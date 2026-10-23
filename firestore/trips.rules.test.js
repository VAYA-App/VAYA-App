// Security tests for firestore.rules (#145). Run on the Firestore emulator:
//   npm test --prefix firestore   (inside `firebase emulators:exec`)
// or `npm run test:emulator --prefix firestore`, which starts it.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const rules = readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8');

/** The shape of Trip.toJson(). */
function trip(ownerUid, overrides = {}) {
  return {
    ownerUid,
    createdAt: '2026-11-01T00:00:00.000Z',
    updatedAt: '2026-11-01T00:00:00.000Z',
    request: { travellerCount: 2, budget: 6000, note: 'ไม่ทานเผ็ด' },
    plan: { destinationId: 'chonburi', days: [] },
    ...overrides,
  };
}

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-vaya',
    firestore: { rules },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  // Seed alice's trip without the rules.
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'trips/alice-trip'), trip('alice'));
  });
});

const alice = () => env.authenticatedContext('alice').firestore();
const bob = () => env.authenticatedContext('bob').firestore();
const guest = () => env.unauthenticatedContext().firestore();

describe('reading', () => {
  test('the owner can read their trip', async () => {
    await assertSucceeds(getDoc(doc(alice(), 'trips/alice-trip')));
  });

  test('another user cannot read it', async () => {
    await assertFails(getDoc(doc(bob(), 'trips/alice-trip')));
  });

  test('a signed-out visitor cannot read it', async () => {
    await assertFails(getDoc(doc(guest(), 'trips/alice-trip')));
  });

  test('listing works only filtered to your own trips', async () => {
    const trips = collection(alice(), 'trips');
    await assertSucceeds(getDocs(query(trips, where('ownerUid', '==', 'alice'))));
    await assertFails(getDocs(trips));
    await assertFails(
      getDocs(query(collection(bob(), 'trips'), where('ownerUid', '==', 'alice'))),
    );
  });
});

describe('creating', () => {
  test('a user can create a valid trip for themself', async () => {
    await assertSucceeds(setDoc(doc(bob(), 'trips/bob-trip'), trip('bob')));
  });

  test('nobody can create a trip for someone else', async () => {
    await assertFails(setDoc(doc(bob(), 'trips/fake'), trip('alice')));
    await assertFails(setDoc(doc(guest(), 'trips/fake'), trip('alice')));
  });

  test('a malformed trip is rejected', async () => {
    const bad = [
      trip('bob', { request: { travellerCount: 0, budget: 6000 } }),
      trip('bob', { request: { travellerCount: 11, budget: 6000 } }),
      trip('bob', { request: { travellerCount: 2, budget: -1 } }),
      trip('bob', { request: { travellerCount: 2, budget: 2000000 } }),
      trip('bob', { request: { travellerCount: 2, budget: 6000, note: 'x'.repeat(501) } }),
      trip('bob', { plan: 'not a map' }),
      trip('bob', { isAdmin: true }),
    ];
    for (const [i, data] of bad.entries()) {
      await assertFails(setDoc(doc(bob(), `trips/bad-${i}`), data));
    }
    const { plan, ...noPlan } = trip('bob');
    await assertFails(setDoc(doc(bob(), 'trips/no-plan'), noPlan));
  });
});

describe('updating', () => {
  test('the owner can update their trip', async () => {
    await assertSucceeds(
      updateDoc(doc(alice(), 'trips/alice-trip'), {
        updatedAt: '2026-11-02T00:00:00.000Z',
      }),
    );
  });

  test('the owner cannot give the trip away or rewrite createdAt', async () => {
    await assertFails(updateDoc(doc(alice(), 'trips/alice-trip'), { ownerUid: 'bob' }));
    await assertFails(
      updateDoc(doc(alice(), 'trips/alice-trip'), {
        createdAt: '2020-01-01T00:00:00.000Z',
      }),
    );
  });

  test('another user cannot change it, even to take it over', async () => {
    await assertFails(
      updateDoc(doc(bob(), 'trips/alice-trip'), { updatedAt: '2026-11-02T00:00:00.000Z' }),
    );
    await assertFails(setDoc(doc(bob(), 'trips/alice-trip'), trip('bob')));
  });
});

describe('deleting', () => {
  test('only the owner can delete', async () => {
    await assertFails(deleteDoc(doc(bob(), 'trips/alice-trip')));
    await assertFails(deleteDoc(doc(guest(), 'trips/alice-trip')));
    await assertSucceeds(deleteDoc(doc(alice(), 'trips/alice-trip')));
  });
});

describe('everything else', () => {
  test('other collections are closed', async () => {
    await assertFails(getDoc(doc(alice(), 'users/alice')));
    await assertFails(setDoc(doc(alice(), 'users/alice'), { role: 'admin' }));
  });
});
