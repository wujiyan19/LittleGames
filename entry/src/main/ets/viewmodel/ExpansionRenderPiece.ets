import { ExpansionPiece } from '../model/game/ExpansionState';

/** Stable UI identity with an observable snapshot; the model stays serializable. */
@ObservedV2
export class ExpansionRenderPiece {
  readonly id: number;
  @Trace piece: ExpansionPiece;

  constructor(piece: ExpansionPiece) {
    this.id = piece.id;
    this.piece = piece;
  }
}
