/// 0 — средняя линия стана. Шаг позиции — полпромежутка между линейками.
double staffNoteY(
  int position, {
  double top = 36,
  double lineGap = 12,
}) {
  final middle = top + 2 * lineGap;
  return middle - position * (lineGap / 2);
}
