import { GameCategory, GameInfo } from '../common/GameConstants';

/** Catalog for independently implemented collection games. */
export function collectionGames(): GameInfo[] {
  return [
    { id: 'tictactoe', name: $r('app.string.game_tictactoe_name'), category: GameCategory.BOARD,
      icon: $r('app.media.game_tictactoe'), description: $r('app.string.game_tictactoe_desc'),
      highScore: 0, playCount: 0, scoreLabel: $r('app.string.collection_duel_score') },
    { id: 'gomoku', name: $r('app.string.game_gomoku_name'), category: GameCategory.BOARD,
      icon: $r('app.media.game_gomoku'), description: $r('app.string.game_gomoku_desc'),
      highScore: 0, playCount: 0, scoreLabel: $r('app.string.collection_duel_score') },
    { id: 'reversi', name: $r('app.string.game_reversi_name'), category: GameCategory.BOARD,
      icon: $r('app.media.game_reversi'), description: $r('app.string.game_reversi_desc'),
      highScore: 0, playCount: 0, scoreLabel: $r('app.string.collection_duel_score') },
    { id: 'fourline', name: $r('app.string.game_fourline_name'), category: GameCategory.BOARD,
      icon: $r('app.media.game_fourline'), description: $r('app.string.game_fourline_desc'),
      highScore: 0, playCount: 0, scoreLabel: $r('app.string.collection_duel_score') },
    { id: 'nim', name: $r('app.string.game_nim_name'), category: GameCategory.BOARD,
      icon: $r('app.media.game_nim'), description: $r('app.string.game_nim_desc'),
      highScore: 0, playCount: 0, scoreLabel: $r('app.string.collection_duel_score') },
    { id: 'lights', name: $r('app.string.game_lights_name'), category: GameCategory.PUZZLE,
      icon: $r('app.media.game_lights'), description: $r('app.string.game_lights_desc'),
      highScore: 0, playCount: 0, scoreLabel: $r('app.string.collection_score') },
    { id: 'flood', name: $r('app.string.game_flood_name'), category: GameCategory.PUZZLE,
      icon: $r('app.media.game_flood'), description: $r('app.string.game_flood_desc'),
      highScore: 0, playCount: 0, scoreLabel: $r('app.string.collection_score') },
    { id: 'maze', name: $r('app.string.game_maze_name'), category: GameCategory.PUZZLE,
      icon: $r('app.media.game_maze'), description: $r('app.string.game_maze_desc'),
      highScore: 0, playCount: 0, scoreLabel: $r('app.string.collection_score') },
    { id: 'hanoi', name: $r('app.string.game_hanoi_name'), category: GameCategory.PUZZLE,
      icon: $r('app.media.game_hanoi'), description: $r('app.string.game_hanoi_desc'),
      highScore: 0, playCount: 0, scoreLabel: $r('app.string.collection_score') },
    { id: 'peg', name: $r('app.string.game_peg_name'), category: GameCategory.PUZZLE,
      icon: $r('app.media.game_peg'), description: $r('app.string.game_peg_desc'),
      highScore: 0, playCount: 0, scoreLabel: $r('app.string.collection_score') },
    { id: 'nonogram', name: $r('app.string.game_nonogram_name'), category: GameCategory.PUZZLE,
      icon: $r('app.media.game_nonogram'), description: $r('app.string.game_nonogram_desc'),
      highScore: 0, playCount: 0, scoreLabel: $r('app.string.collection_score') },
    { id: 'arithmetic', name: $r('app.string.game_arithmetic_name'), category: GameCategory.NUMBER,
      icon: $r('app.media.game_arithmetic'), description: $r('app.string.game_arithmetic_desc'),
      highScore: 0, playCount: 0, scoreLabel: $r('app.string.collection_score') },
    { id: 'compare', name: $r('app.string.game_compare_name'), category: GameCategory.NUMBER,
      icon: $r('app.media.game_compare'), description: $r('app.string.game_compare_desc'),
      highScore: 0, playCount: 0, scoreLabel: $r('app.string.collection_score') },
    { id: 'sequence', name: $r('app.string.game_sequence_name'), category: GameCategory.NUMBER,
      icon: $r('app.media.game_sequence'), description: $r('app.string.game_sequence_desc'),
      highScore: 0, playCount: 0, scoreLabel: $r('app.string.collection_score') },
    { id: 'binary', name: $r('app.string.game_binary_name'), category: GameCategory.NUMBER,
      icon: $r('app.media.game_binary'), description: $r('app.string.game_binary_desc'),
      highScore: 0, playCount: 0, scoreLabel: $r('app.string.collection_score') },
    { id: 'targetsum', name: $r('app.string.game_targetsum_name'), category: GameCategory.NUMBER,
      icon: $r('app.media.game_targetsum'), description: $r('app.string.game_targetsum_desc'),
      highScore: 0, playCount: 0, scoreLabel: $r('app.string.collection_score') },
    { id: 'schulte', name: $r('app.string.game_schulte_name'), category: GameCategory.MEMORY,
      icon: $r('app.media.game_schulte'), description: $r('app.string.game_schulte_desc'),
      highScore: 0, playCount: 0, scoreLabel: $r('app.string.collection_score') },
    { id: 'memorysequence', name: $r('app.string.game_memorysequence_name'), category: GameCategory.MEMORY,
      icon: $r('app.media.game_memorysequence'), description: $r('app.string.game_memorysequence_desc'),
      highScore: 0, playCount: 0, scoreLabel: $r('app.string.collection_score') },
    { id: 'missing', name: $r('app.string.game_missing_name'), category: GameCategory.MEMORY,
      icon: $r('app.media.game_missing'), description: $r('app.string.game_missing_desc'),
      highScore: 0, playCount: 0, scoreLabel: $r('app.string.collection_score') },
    { id: 'reaction', name: $r('app.string.game_reaction_name'), category: GameCategory.REACTION,
      icon: $r('app.media.game_reaction'), description: $r('app.string.game_reaction_desc'),
      highScore: 0, playCount: 0, scoreLabel: $r('app.string.collection_score') }
  ];
}

export function collectionRules(id: string): Resource {
  if (id === 'tictactoe') { return $r('app.string.game_tictactoe_rules'); }
  if (id === 'gomoku') { return $r('app.string.game_gomoku_rules'); }
  if (id === 'reversi') { return $r('app.string.game_reversi_rules'); }
  if (id === 'fourline') { return $r('app.string.game_fourline_rules'); }
  if (id === 'nim') { return $r('app.string.game_nim_rules'); }
  if (id === 'lights') { return $r('app.string.game_lights_rules'); }
  if (id === 'flood') { return $r('app.string.game_flood_rules'); }
  if (id === 'maze') { return $r('app.string.game_maze_rules'); }
  if (id === 'hanoi') { return $r('app.string.game_hanoi_rules'); }
  if (id === 'peg') { return $r('app.string.game_peg_rules'); }
  if (id === 'nonogram') { return $r('app.string.game_nonogram_rules'); }
  if (id === 'arithmetic') { return $r('app.string.game_arithmetic_rules'); }
  if (id === 'compare') { return $r('app.string.game_compare_rules'); }
  if (id === 'sequence') { return $r('app.string.game_sequence_rules'); }
  if (id === 'binary') { return $r('app.string.game_binary_rules'); }
  if (id === 'targetsum') { return $r('app.string.game_targetsum_rules'); }
  if (id === 'schulte') { return $r('app.string.game_schulte_rules'); }
  if (id === 'memorysequence') { return $r('app.string.game_memorysequence_rules'); }
  if (id === 'missing') { return $r('app.string.game_missing_rules'); }
  if (id === 'reaction') { return $r('app.string.game_reaction_rules'); }
  return $r('app.string.collection_rules');
}
