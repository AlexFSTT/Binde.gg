/// Match mode configurations.
enum MatchMode {
  oneVsOne('1v1', 1, 2),
  twoVsTwo('2v2', 2, 4),
  fiveVsFive('5v5', 5, 10);

  const MatchMode(this.label, this.playersPerTeam, this.totalPlayers);

  final String label;
  final int playersPerTeam;
  final int totalPlayers;
}

/// Available matchmaking regions.
enum Region {
  eu('EU', 'Europe'),
  na('NA', 'North America'),
  sa('SA', 'South America'),
  asia('AS', 'Asia'),
  oc('OC', 'Oceania');

  const Region(this.code, this.label);

  final String code;
  final String label;
}
