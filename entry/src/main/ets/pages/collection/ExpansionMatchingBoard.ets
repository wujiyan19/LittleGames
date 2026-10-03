import { ExpansionViewModel } from '../../viewmodel/ExpansionViewModel';
import { ExpansionPiece } from '../../model/game/ExpansionState';
import { SemanticColors, FontTokens, SpacingTokens, RadiusTokens } from '../../common/DesignTokens';
import { range } from '../../common/Range';
import { ExpansionArt } from '../../common/ExpansionArt';
import { GameArtTile } from '../../components/GameArtTile';

@ComponentV2
export struct ExpansionMatchingBoard {
  @Param gameId: string = '';
  @Param vm: ExpansionViewModel = new ExpansionViewModel();
  @Local boardWidth: number = 320;
  color(value: number): Resource {
    const palette: Resource[] = [$r('app.color.expansion_color_1'), $r('app.color.expansion_color_2'), $r('app.color.expansion_color_3'),
      $r('app.color.expansion_color_4'), $r('app.color.expansion_color_5'), $r('app.color.expansion_color_6')];
    return value <= 0 ? SemanticColors.surface : palette[(value - 1) % 6];
  }
  symbol(value: number): string { return value <= 0 ? '' : ['◆', '●', '★', '▲', '♥', '✿'][(value - 1) % 6]; }
  measure(area: Area): void { const width: number = Number(area.width); if (Number.isFinite(width) && width > 0) { this.boardWidth = width; } }
  unit(): number { return this.boardWidth / (this.gameId === 'linktiles' ? 8 : 6); }
  pathPoint(cell: number): number[] { return [(cell % 8 + 0.5) * this.unit(), (Math.floor(cell / 8) + 0.5) * this.unit()]; }
  build() {
    Column({ space: SpacingTokens.base }) {
      if (this.gameId === 'mahjongsolitaire') { this.Mahjong() } else { this.Board() }
      if (this.gameId === 'linktiles' || this.gameId === 'mahjongsolitaire') {
        Button($r('app.string.expansion_rearrange')).onClick(() => { this.vm.action(); })
      }
      if (this.gameId === 'groupclear') {
        Text($r('app.string.expansion_target', this.vm.state.goal)).fontColor(SemanticColors.textSecondary)
      }
      if (this.gameId === 'slotpair') {
        Row({ space: SpacingTokens.sm }) {
          Text($r('app.string.expansion_next_tile')).fontColor(SemanticColors.textSecondary)
          Image(ExpansionArt.tile(this.vm.state.next - 1)).width(38).height(38).objectFit(ImageFit.Contain)
          Text($r('app.string.expansion_progress', this.vm.state.cursor, this.vm.state.goal)).fontColor(SemanticColors.textSecondary)
        }
        Row({ space: SpacingTokens.xs }) {
          ForEach(range(6), (col: number) => {
            Button('↓').layoutWeight(1).height($r('app.float.expansion_control_height'))
              .accessibilityText($r('app.string.expansion_drop_column', col + 1)).onClick(() => { this.vm.tap(col); })
          }, (col: number) => col.toString())
        }.width('100%')
      }
    }.width('100%')
  }
  @Builder
  Board() {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach(this.vm.state.board, (value: number, index: number) => {
        Column() { GameArtTile({ image: value === 0 ? $r('app.media.exp_empty') : ExpansionArt.tile(value - 1),
          selected: this.vm.state.selected === index || this.vm.state.tray.includes(index),
          description: $r('app.string.expansion_cell', Math.floor(index / 6) + 1, index % 6 + 1, this.symbol(value)),
          onTap: () => { this.vm.tap(this.gameId === 'slotpair' ? index % 6 : index); } }) }.width(this.unit() - 4).height(this.unit() - 4)
          .opacity(value === 0 ? 0.2 : 1)
          .translate({ x: (index % 6 + (this.gameId === 'linktiles' ? 1 : 0)) * this.unit() + 2,
            y: (Math.floor(index / 6) + (this.gameId === 'linktiles' ? 1 : 0)) * this.unit() + 2 })
          .accessibilityText($r('app.string.expansion_cell', Math.floor(index / 6) + 1, index % 6 + 1, this.symbol(value)))
      }, (value: number, index: number) => index.toString())
      if (this.gameId === 'linktiles') {
        ForEach(range(Math.max(0, this.vm.state.data.length - 1)), (segment: number) => {
          Line().width('100%').height('100%').startPoint(this.pathPoint(this.vm.state.data[segment]))
            .endPoint(this.pathPoint(this.vm.state.data[segment + 1])).strokeWidth(3).stroke(SemanticColors.success).hitTestBehavior(HitTestMode.None)
        }, (segment: number) => segment.toString())
      }
    }.width('100%').aspectRatio((this.gameId === 'linktiles' ? 8 : 6) / (this.vm.state.rows + (this.gameId === 'linktiles' ? 2 : 0)))
      .backgroundColor(SemanticColors.boardBg).backgroundImage(ExpansionArt.board(this.gameId)).backgroundImageSize({ width: '100%', height: '100%' }).borderRadius(RadiusTokens.base).onAreaChange((oldArea: Area, area: Area) => { this.measure(area); })
  }
  @Builder
  Mahjong() {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach(this.vm.state.pieces, (tile: ExpansionPiece) => {
        if (tile.alive) {
          Column() { GameArtTile({ image: ExpansionArt.tile(tile.color - 1), selected: this.vm.state.selected === tile.id || this.vm.state.tray.includes(tile.id),
            description: $r('app.string.expansion_mahjong_tile', tile.id + 1, this.symbol(tile.color), tile.owner + 1), onTap: () => { this.vm.tap(tile.id); } }) }
            .width(this.unit() - 7).height(this.unit() - 7)
            .opacity(this.vm.tileFree(tile.id) ? 1 : 0.5)
            .translate({ x: tile.x * this.unit() + 2 + tile.owner * 2, y: tile.y * this.unit() + 2 + tile.owner * 2 })
            .accessibilityText($r('app.string.expansion_mahjong_tile', tile.id + 1, this.symbol(tile.color), tile.owner + 1))
        }
      }, (tile: ExpansionPiece) => tile.id.toString())
    }.width('100%').aspectRatio(6 / 4).backgroundColor(SemanticColors.boardBg).backgroundImage(ExpansionArt.board(this.gameId)).backgroundImageSize({ width: '100%', height: '100%' }).borderRadius(RadiusTokens.base)
      .onAreaChange((oldArea: Area, area: Area) => { this.measure(area); })
  }
}
