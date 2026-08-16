/// One day's total in the daily sales report (FR-071) — one entry per day,
/// trailing 7 days including today, `totalMinorUnits: 0` for a day with no
/// completed sales rather than the day being omitted.
class DailySalesEntry {
  const DailySalesEntry({required this.date, required this.totalMinorUnits});

  final DateTime date;
  final int totalMinorUnits;
}
