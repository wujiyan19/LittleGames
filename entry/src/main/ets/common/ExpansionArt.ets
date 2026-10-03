/** Generated resource selectors; see scripts/generate-expansion-art.cjs. */
import { ExpansionPiece } from '../model/game/ExpansionState';

export class ExpansionArt {
  static board(id: string): Resource {
    if (id === 'blockfit') { return $r('app.media.exp_board_blockfit'); }
    if (id === 'tilestack') { return $r('app.media.exp_board_tilestack'); }
    if (id === 'bubbleshooter') { return $r('app.media.exp_board_bubbleshooter'); }
    if (id === 'fruitmerge') { return $r('app.media.exp_board_fruitmerge'); }
    if (id === 'watersort') { return $r('app.media.exp_board_watersort'); }
    if (id === 'arrowclear') { return $r('app.media.exp_board_arrowclear'); }
    if (id === 'screwout') { return $r('app.media.exp_board_screwout'); }
    if (id === 'parkingjam') { return $r('app.media.exp_board_parkingjam'); }
    if (id === 'runner') { return $r('app.media.exp_board_runner'); }
    if (id === 'blackhole') { return $r('app.media.exp_board_blackhole'); }
    if (id === 'fisheat') { return $r('app.media.exp_board_fisheat'); }
    if (id === 'sokoban') { return $r('app.media.exp_board_sokoban'); }
    if (id === 'pipes') { return $r('app.media.exp_board_pipes'); }
    if (id === 'differences') { return $r('app.media.exp_board_differences'); }
    if (id === 'roomdefense') { return $r('app.media.exp_board_roomdefense'); }
    if (id === 'basketball') { return $r('app.media.exp_board_basketball'); }
    if (id === 'solitaire') { return $r('app.media.exp_board_solitaire'); }
    if (id === 'characters') { return $r('app.media.exp_board_characters'); }
    if (id === 'rhythm') { return $r('app.media.exp_board_rhythm'); }
    if (id === 'restaurant') { return $r('app.media.exp_board_restaurant'); }
    if (id === 'linktiles') { return $r('app.media.exp_board_linktiles'); }
    if (id === 'mahjongsolitaire') { return $r('app.media.exp_board_mahjongsolitaire'); }
    if (id === 'groupclear') { return $r('app.media.exp_board_groupclear'); }
    if (id === 'slotpair') { return $r('app.media.exp_board_slotpair'); }
    if (id === 'buscolor') { return $r('app.media.exp_board_buscolor'); }
    if (id === 'yarn') { return $r('app.media.exp_board_yarn'); }
    if (id === 'sand') { return $r('app.media.exp_board_sand'); }
    if (id === 'untangle') { return $r('app.media.exp_board_untangle'); }
    if (id === 'platformer') { return $r('app.media.exp_board_platformer'); }
    if (id === 'grapple') { return $r('app.media.exp_board_grapple'); }
    if (id === 'flappy') { return $r('app.media.exp_board_flappy'); }
    if (id === 'fruitslice') { return $r('app.media.exp_board_fruitslice'); }
    if (id === 'rollingball') { return $r('app.media.exp_board_rollingball'); }
    if (id === 'shooter') { return $r('app.media.exp_board_shooter'); }
    if (id === 'tanks') { return $r('app.media.exp_board_tanks'); }
    if (id === 'fortress') { return $r('app.media.exp_board_fortress'); }
    if (id === 'survival') { return $r('app.media.exp_board_survival'); }
    if (id === 'backpack') { return $r('app.media.exp_board_backpack'); }
    if (id === 'billiards') { return $r('app.media.exp_board_billiards'); }
    if (id === 'penalty') { return $r('app.media.exp_board_penalty'); }
    if (id === 'pingpong') { return $r('app.media.exp_board_pingpong'); }
    if (id === 'bowling') { return $r('app.media.exp_board_bowling'); }
    if (id === 'golf') { return $r('app.media.exp_board_golf'); }
    if (id === 'drift') { return $r('app.media.exp_board_drift'); }
    if (id === 'hillclimb') { return $r('app.media.exp_board_hillclimb'); }
    if (id === 'airhockey') { return $r('app.media.exp_board_airhockey'); }
    if (id === 'tug') { return $r('app.media.exp_board_tug'); }
    if (id === 'dots') { return $r('app.media.exp_board_dots'); }
    if (id === 'doudizhu') { return $r('app.media.exp_board_doudizhu'); }
    if (id === 'guandan') { return $r('app.media.exp_board_guandan'); }
    if (id === 'mahjong') { return $r('app.media.exp_board_mahjong'); }
    if (id === 'xiangqi') { return $r('app.media.exp_board_xiangqi'); }
    if (id === 'chess') { return $r('app.media.exp_board_chess'); }
    if (id === 'ludo') { return $r('app.media.exp_board_ludo'); }
    if (id === 'spider') { return $r('app.media.exp_board_spider'); }
    if (id === 'freecell') { return $r('app.media.exp_board_freecell'); }
    if (id === 'onestroke') { return $r('app.media.exp_board_onestroke'); }
    if (id === 'hiddenobjects') { return $r('app.media.exp_board_hiddenobjects'); }
    if (id === 'linerescue') { return $r('app.media.exp_board_linerescue'); }
    if (id === 'picturepuzzle') { return $r('app.media.exp_board_picturepuzzle'); }
    if (id === 'idiom') { return $r('app.media.exp_board_idiom'); }
    if (id === 'wordtower') { return $r('app.media.exp_board_wordtower'); }
    if (id === 'beatjump') { return $r('app.media.exp_board_beatjump'); }
    if (id === 'melody') { return $r('app.media.exp_board_melody'); }
    if (id === 'farm') { return $r('app.media.exp_board_farm'); }
    if (id === 'decorate') { return $r('app.media.exp_board_decorate'); }
    if (id === 'fishing') { return $r('app.media.exp_board_fishing'); }
    return $r('app.media.exp_board_blockfit');
  }
  static sportBall(value: number): Resource {
    const images: Resource[] = [$r('app.media.exp_sportball_0'), $r('app.media.exp_sportball_1'), $r('app.media.exp_sportball_2'), $r('app.media.exp_sportball_3'), $r('app.media.exp_sportball_4'), $r('app.media.exp_sportball_5')];
    return images[Math.max(0, Math.min(5, Math.floor(value)))];
  }
  static water(value: number): Resource {
    const images: Resource[] = [$r('app.media.exp_water_0'), $r('app.media.exp_water_1'), $r('app.media.exp_water_2'), $r('app.media.exp_water_3'), $r('app.media.exp_water_4'), $r('app.media.exp_water_5')];
    return images[Math.max(0, Math.min(5, Math.floor(value)))];
  }
  static arrow(value: number): Resource {
    const images: Resource[] = [$r('app.media.exp_arrow_0'), $r('app.media.exp_arrow_1'), $r('app.media.exp_arrow_2'), $r('app.media.exp_arrow_3')];
    return images[Math.max(0, Math.min(3, Math.floor(value)))];
  }
  static pipe(value: number): Resource {
    const images: Resource[] = [$r('app.media.exp_pipe_0'), $r('app.media.exp_pipe_1'), $r('app.media.exp_pipe_2'), $r('app.media.exp_pipe_3'), $r('app.media.exp_pipe_4'), $r('app.media.exp_pipe_5'), $r('app.media.exp_pipe_6'), $r('app.media.exp_pipe_7'), $r('app.media.exp_pipe_8'), $r('app.media.exp_pipe_9'), $r('app.media.exp_pipe_10'), $r('app.media.exp_pipe_11'), $r('app.media.exp_pipe_12'), $r('app.media.exp_pipe_13'), $r('app.media.exp_pipe_14'), $r('app.media.exp_pipe_15')];
    return images[Math.max(0, Math.min(15, Math.floor(value)))];
  }
  static tile(value: number): Resource {
    const images: Resource[] = [$r('app.media.exp_tile_0'), $r('app.media.exp_tile_1'), $r('app.media.exp_tile_2'), $r('app.media.exp_tile_3'), $r('app.media.exp_tile_4'), $r('app.media.exp_tile_5')];
    return images[Math.max(0, Math.min(5, Math.floor(value)))];
  }
  static block(value: number): Resource {
    const images: Resource[] = [$r('app.media.exp_block_0'), $r('app.media.exp_block_1'), $r('app.media.exp_block_2'), $r('app.media.exp_block_3'), $r('app.media.exp_block_4'), $r('app.media.exp_block_5')];
    return images[Math.max(0, Math.min(5, Math.floor(value)))];
  }
  static bubble(value: number): Resource {
    const images: Resource[] = [$r('app.media.exp_bubble_0'), $r('app.media.exp_bubble_1'), $r('app.media.exp_bubble_2'), $r('app.media.exp_bubble_3'), $r('app.media.exp_bubble_4'), $r('app.media.exp_bubble_5')];
    return images[Math.max(0, Math.min(5, Math.floor(value)))];
  }
  static fruit(value: number): Resource {
    const images: Resource[] = [$r('app.media.exp_fruit_0'), $r('app.media.exp_fruit_1'), $r('app.media.exp_fruit_2'), $r('app.media.exp_fruit_3'), $r('app.media.exp_fruit_4'), $r('app.media.exp_fruit_5'), $r('app.media.exp_fruit_6'), $r('app.media.exp_fruit_7'), $r('app.media.exp_fruit_8'), $r('app.media.exp_fruit_9')];
    return images[Math.max(0, Math.min(9, Math.floor(value)))];
  }
  static object(value: number): Resource {
    const images: Resource[] = [$r('app.media.exp_object_0'), $r('app.media.exp_object_1'), $r('app.media.exp_object_2'), $r('app.media.exp_object_3'), $r('app.media.exp_object_4'), $r('app.media.exp_object_5'), $r('app.media.exp_object_6'), $r('app.media.exp_object_7'), $r('app.media.exp_object_8')];
    return images[Math.max(0, Math.min(8, Math.floor(value)))];
  }
  static fish(value: number): Resource {
    const images: Resource[] = [$r('app.media.exp_fish_0'), $r('app.media.exp_fish_1'), $r('app.media.exp_fish_2'), $r('app.media.exp_fish_3'), $r('app.media.exp_fish_4'), $r('app.media.exp_fish_5')];
    return images[Math.max(0, Math.min(5, Math.floor(value)))];
  }
  static bus(value: number): Resource {
    const images: Resource[] = [$r('app.media.exp_bus_0'), $r('app.media.exp_bus_1'), $r('app.media.exp_bus_2'), $r('app.media.exp_bus_3'), $r('app.media.exp_bus_4'), $r('app.media.exp_bus_5')];
    return images[Math.max(0, Math.min(5, Math.floor(value)))];
  }
  static car(value: number): Resource {
    const images: Resource[] = [$r('app.media.exp_car_0'), $r('app.media.exp_car_1'), $r('app.media.exp_car_2'), $r('app.media.exp_car_3'), $r('app.media.exp_car_4'), $r('app.media.exp_car_5')];
    return images[Math.max(0, Math.min(5, Math.floor(value)))];
  }
  static yarn(value: number): Resource {
    const images: Resource[] = [$r('app.media.exp_yarn_0'), $r('app.media.exp_yarn_1'), $r('app.media.exp_yarn_2'), $r('app.media.exp_yarn_3'), $r('app.media.exp_yarn_4'), $r('app.media.exp_yarn_5')];
    return images[Math.max(0, Math.min(5, Math.floor(value)))];
  }
  static reel(value: number): Resource {
    const images: Resource[] = [$r('app.media.exp_reel_0'), $r('app.media.exp_reel_1'), $r('app.media.exp_reel_2'), $r('app.media.exp_reel_3'), $r('app.media.exp_reel_4'), $r('app.media.exp_reel_5')];
    return images[Math.max(0, Math.min(5, Math.floor(value)))];
  }
  static sand(value: number): Resource {
    const images: Resource[] = [$r('app.media.exp_sand_0'), $r('app.media.exp_sand_1'), $r('app.media.exp_sand_2'), $r('app.media.exp_sand_3'), $r('app.media.exp_sand_4'), $r('app.media.exp_sand_5')];
    return images[Math.max(0, Math.min(5, Math.floor(value)))];
  }
  static nozzle(value: number): Resource {
    const images: Resource[] = [$r('app.media.exp_nozzle_0'), $r('app.media.exp_nozzle_1'), $r('app.media.exp_nozzle_2'), $r('app.media.exp_nozzle_3'), $r('app.media.exp_nozzle_4'), $r('app.media.exp_nozzle_5')];
    return images[Math.max(0, Math.min(5, Math.floor(value)))];
  }
  static person(value: number): Resource {
    const images: Resource[] = [$r('app.media.exp_person_0'), $r('app.media.exp_person_1'), $r('app.media.exp_person_2'), $r('app.media.exp_person_3'), $r('app.media.exp_person_4'), $r('app.media.exp_person_5')];
    return images[Math.max(0, Math.min(5, Math.floor(value)))];
  }
  static food(value: number): Resource {
    const images: Resource[] = [$r('app.media.exp_food_0'), $r('app.media.exp_food_1'), $r('app.media.exp_food_2')];
    return images[Math.max(0, Math.min(2, Math.floor(value)))];
  }
  static chess(piece: number): Resource {
    const light: Resource[] = [$r('app.media.exp_chess_0_0'), $r('app.media.exp_chess_0_1'), $r('app.media.exp_chess_0_2'), $r('app.media.exp_chess_0_3'), $r('app.media.exp_chess_0_4'), $r('app.media.exp_chess_0_5')];
    const dark: Resource[] = [$r('app.media.exp_chess_1_0'), $r('app.media.exp_chess_1_1'), $r('app.media.exp_chess_1_2'), $r('app.media.exp_chess_1_3'), $r('app.media.exp_chess_1_4'), $r('app.media.exp_chess_1_5')];
    return (piece > 10 ? dark : light)[Math.max(0, Math.min(5, piece % 10 - 1))];
  }
  static farm(value: number): Resource {
    const images: Resource[] = [$r('app.media.exp_soil'), $r('app.media.exp_seedling'), $r('app.media.exp_watered'), $r('app.media.exp_crop')];
    return images[Math.max(0, Math.min(3, value))];
  }
  static furniture(value: number): Resource {
    const images: Resource[] = [$r('app.media.exp_floor'), $r('app.media.exp_sofa'), $r('app.media.exp_table'), $r('app.media.exp_plant'), $r('app.media.exp_lamp')];
    return images[Math.max(0, Math.min(4, value))];
  }
  static equipment(value: number): Resource {
    const images: Resource[] = [$r('app.media.exp_sword'), $r('app.media.exp_shield'), $r('app.media.exp_potion'), $r('app.media.exp_boots')];
    return images[Math.max(0, Math.min(3, value))];
  }
  static piece(id: string, p: ExpansionPiece): Resource {
    if (id === 'fruitmerge') { return ExpansionArt.fruit(p.color); }
    if (id === 'fisheat') { return ExpansionArt.fish(p.kind === 10 ? 0 : (p.color + 1) % 6); }
    if (id === 'bubbleshooter') { return ExpansionArt.bubble(p.color - 1); }
    if (p.kind === 6) { return $r('app.media.exp_runner'); }
    if (p.kind === 7) { return p.color === 1 ? $r('app.media.exp_coin') : $r('app.media.exp_barrier'); }
    if (p.kind === 8 || p.kind === 42) { return $r('app.media.exp_hole'); }
    if (p.kind === 9) { return ExpansionArt.object((p.color - 1) % 6); }
    if (p.kind === 13) { return $r('app.media.exp_door'); }
    if (p.kind === 14) { return $r('app.media.exp_tower'); }
    if (p.kind === 15 || p.kind === 56) { return id === 'linerescue' ? $r('app.media.exp_bee') : $r('app.media.exp_enemy'); }
    if (p.kind === 16) { return $r('app.media.exp_hoop'); }
    if (p.kind === 17) { return $r('app.media.exp_basketball'); }
    if (p.kind === 18) { return $r('app.media.exp_note'); }
    if (p.kind === 24) { return id === 'shooter' ? $r('app.media.exp_plane') : id === 'tanks' ? $r('app.media.exp_tank') : id === 'fortress' ? $r('app.media.exp_tower') : id === 'flappy' ? $r('app.media.exp_bird') : $r('app.media.exp_robot'); }
    if (p.kind === 25 || p.kind === 26) { return $r('app.media.exp_platform'); }
    if (p.kind === 27 || p.kind === 43) { return $r('app.media.exp_flag'); }
    if (p.kind === 28) { return $r('app.media.exp_anchor'); }
    if (p.kind === 30) { return ExpansionArt.fruit([0, 3, 4, 5, 6, 1][Math.max(0, (p.color - 1) % 6)]); }
    if (p.kind === 31) { return $r('app.media.exp_bomb'); }
    if (p.kind === 58) { return $r('app.media.exp_ball'); }
    if (p.kind === 32 && (id === 'billiards' || id === 'golf')) { return p.color === 1 || id === 'golf' ? $r('app.media.exp_cueball') : ExpansionArt.sportBall(p.color - 2); }
    if (p.kind === 32 && id === 'bowling') { return $r('app.media.exp_bowlingball'); }
    if (p.kind === 32) { return id === 'penalty' ? $r('app.media.exp_soccer') : id === 'airhockey' ? $r('app.media.exp_puck') : $r('app.media.exp_ball'); }
    if (p.kind === 33) { return id === 'tanks' ? $r('app.media.exp_tank') : $r('app.media.exp_enemy'); }
    if (p.kind === 34) { return $r('app.media.exp_bullet'); }
    if (p.kind === 36) { return ExpansionArt.car(id === 'drift' ? 0 : 3); }
    if (p.kind === 37) { return $r('app.media.exp_pin'); }
    if (p.kind === 39) { return id === 'airhockey' ? $r('app.media.exp_striker') : $r('app.media.exp_paddle'); }
    if (p.kind === 44) { return $r('app.media.exp_glove'); }
    if (p.kind === 55) { return $r('app.media.exp_dog'); }
    return ExpansionArt.tile(Math.max(0, p.color - 1) % 6);
  }
}
