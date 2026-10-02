/** First-party materials shared by collection icons and interactive game pieces. */
export class CollectionArt {
  static board(id: string): Resource {
    if (id === 'gomoku' || id === 'peg') { return $r('app.media.col_table_board'); }
    if (id === 'reversi') { return $r('app.media.col_jade_board'); }
    if (id === 'fourline') { return $r('app.media.col_blue_board'); }
    if (id === 'maze') { return $r('app.media.col_garden_board'); }
    if (id === 'lights' || id === 'memorysequence') { return $r('app.media.col_night_board'); }
    if (id === 'nonogram') { return $r('app.media.col_paper_board'); }
    return $r('app.media.col_ceramic_board');
  }
  static flood(value: number): Resource {
    const images: Resource[] = [$r('app.media.col_flood_0'), $r('app.media.col_flood_1'),
      $r('app.media.col_flood_2'), $r('app.media.col_flood_3')];
    return images[value];
  }
  static cell(id: string, value: number): Resource {
    if (id === 'gomoku') { return $r('app.media.col_go_cell'); }
    if (id === 'reversi') { return $r('app.media.col_jade_cell'); }
    if (id === 'fourline') { return $r('app.media.col_drop_hole'); }
    if (id === 'flood') { return CollectionArt.flood(value); }
    if (id === 'lights') { return value === 1 ? $r('app.media.col_light_on') : $r('app.media.col_light_off'); }
    if (id === 'maze') { return value === 1 ? $r('app.media.col_wall') : $r('app.media.col_path'); }
    if (id === 'peg') { return $r('app.media.col_peg_hole'); }
    if (id === 'nonogram') { return value === 1 ? $r('app.media.col_ink_cell') : $r('app.media.col_paper_cell'); }
    return $r('app.media.col_ceramic_cell');
  }
  static piece(id: string, player: number): Resource {
    if (id === 'tictactoe') { return player === 1 ? $r('app.media.col_cross') : $r('app.media.col_ring'); }
    if (id === 'fourline') { return player === 1 ? $r('app.media.col_chip_blue') : $r('app.media.col_chip_coral'); }
    if (id === 'nim') { return $r('app.media.col_stone'); }
    return player === 1 ? $r('app.media.col_stone_dark') : $r('app.media.col_stone_light');
  }
  static question(id: string): Resource {
    return id === 'binary' ? $r('app.media.col_question_binary') : $r('app.media.col_question_paper');
  }
  static disc(index: number): Resource {
    const images: Resource[] = [$r('app.media.col_disc_0'), $r('app.media.col_disc_1'),
      $r('app.media.col_disc_2'), $r('app.media.col_disc_3'), $r('app.media.col_disc_4')];
    return images[index];
  }
  static signal(phase: number): Resource {
    const images: Resource[] = [$r('app.media.col_signal_0'), $r('app.media.col_signal_1'), $r('app.media.col_signal_2')];
    return images[phase];
  }
}
