import '../domain/domain.dart';
import 'cost_calculator.dart';

/// A province that passed [ProvinceFilter], with its cheapest possible
/// total for the request.
typedef ProvinceCandidate = ({Province province, int minimumCost});

/// Pipeline step ②: keeps the provinces a trip can afford and that are not
/// to be avoided in the month it starts, cheapest first. Plain code, run
/// before Gemini ranks them (#25).
class ProvinceFilter {
  const ProvinceFilter(this.costCalculator);

  final CostCalculator costCalculator;

  List<ProvinceCandidate> filter({
    required TripRequest request,
    required PlaceCatalog catalog,
  }) {
    ProvinceCandidate candidate(Province province) => (
      province: province,
      minimumCost: costCalculator.minimumTripCost(
        request: request,
        province: province,
      ),
    );

    // A Destination the user chose is kept as it is.
    if (request.destinationId case final id?) {
      return [candidate(catalog.province(id))];
    }

    final month = request.startDate.month;
    final fits = [
      for (final province in catalog.provinces)
        if (province.seasonFor(month) != SeasonRating.avoid)
          if (candidate(province) case final c
              when c.minimumCost <= request.budget)
            c,
    ];
    return fits..sort((a, b) => a.minimumCost.compareTo(b.minimumCost));
  }
}
