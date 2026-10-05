/// Число ступеней включает оба крайних звука. От до до фа — 4, не 3.
int degreeSpan(int lowerDegree, int upperDegree) => (upperDegree - lowerDegree).abs() + 1;

/// Стадии 1–2 PR-04 открывает L05-01. Уроки L05-07…L05-09 в MVP не входят.
bool pr04EarlyStage(int stage) => stage == 1 || stage == 2;
