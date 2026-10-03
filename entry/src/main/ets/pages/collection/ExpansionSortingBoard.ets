import { ExpansionViewModel } from '../../viewmodel/ExpansionViewModel';
import { ExpansionPiece } from '../../model/game/ExpansionState';
import { SemanticColors, FontTokens, SpacingTokens, RadiusTokens } from '../../common/DesignTokens';
import { range } from '../../common/Range';
import { ExpansionArt } from '../../common/ExpansionArt';

@ComponentV2
export struct ExpansionSortingBoard {
  @Param gameId: string = '';
  @Param vm: ExpansionViewModel = new ExpansionViewModel();
  @Local arenaWidth: number = 320;
  color(value: number): Resource {
    const palette: Resource[] = [$r('app.color.expansion_color_1'), $r('app.color.expansion_color_2'), $r('app.color.expansion_color_3'),
      $r('app.color.expansion_color_4'), $r('app.color.expansion_color_5'), $r('app.color.expansion_color_6')];
    return value <= 0 ? SemanticColors.surface : palette[(value - 1) % 6];
  }
  symbol(value: number): string { return value <= 0 ? '○' : ['◆', '●', '★', '▲', '♥', '✿'][(value - 1) % 6]; }
  colorName(value: number): Resource {
    const names: Resource[] = [$r('app.string.expansion_color_1'), $r('app.string.expansion_color_2'), $r('app.string.expansion_color_3'),
      $r('app.string.expansion_color_4'), $r('app.string.expansion_color_5'), $r('app.string.expansion_color_6')];
    return value <= 0 ? $r('app.string.expansion_empty') : names[(value - 1) % 6];
  }
  arenaScale(): number { return this.arenaWidth / 360; }
  point(id: number): number[] { const p: ExpansionPiece = this.vm.state.pieces[id]; return [p.x * this.arenaScale(), p.y * this.arenaScale()]; }
  measure(area: Area): void { const width: number = Number(area.width); if (Number.isFinite(width) && width > 0) { this.arenaWidth = width; } }
  touch(event: TouchEvent): void {
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.vm.setDragging(false); return; }
    if (event.touches.length === 0) { return; }
    const x: number = event.touches[0].x / this.arenaScale(); const y: number = event.touches[0].y / this.arenaScale();
    if (event.type === TouchType.Down) {
      const node: ExpansionPiece | undefined = this.vm.state.pieces.find((p: ExpansionPiece) => Math.hypot(p.x - x, p.y - y) < 28);
      if (node) { this.vm.setDragging(false); this.vm.tap(node.id); this.vm.setDragging(true); }
    } else if (event.type === TouchType.Move && this.vm.dragging) { this.vm.aim(x, y); }
  }
  build() {
    Column({ space: SpacingTokens.base }) {
      if (this.gameId === 'buscolor') { this.Buses() }
      if (this.gameId === 'yarn') { this.Yarn() }
      if (this.gameId === 'sand') { this.Sand() }
      if (this.gameId === 'untangle') { this.Knots() }
    }.width('100%').padding(SpacingTokens.sm).backgroundImage(ExpansionArt.board(this.gameId)).backgroundImageSize({ width: '100%', height: '100%' }).borderRadius(RadiusTokens.base)
  }
  @Builder
  Bus(bus: ExpansionPiece) {
    Column({ space: SpacingTokens.xs }) {
      Image(ExpansionArt.bus(bus.color - 1)).width('100%').height(55).objectFit(ImageFit.Contain).accessibilityText(this.colorName(bus.color))
      Row({ space: SpacingTokens.xs }) {
        ForEach(range(3), (seat: number) => {
          Text(seat < bus.w ? '●' : '○').fontColor(this.color(bus.color)).fontSize(FontTokens.sizeSubtitle)
        }, (seat: number) => seat.toString())
      }
    }.width('100%').padding(SpacingTokens.sm).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.sm)
  }
  @Builder
  Buses() {
    Column({ space: SpacingTokens.base }) {
      Text($r('app.string.expansion_passenger_queue')).fontColor(SemanticColors.textSecondary)
      Row({ space: SpacingTokens.sm }) {
        ForEach(this.vm.state.board.slice(this.vm.state.cursor, this.vm.state.cursor + 9), (value: number, index: number) => {
          Image(ExpansionArt.person(value - 1)).objectFit(ImageFit.Contain).height(40).layoutWeight(1).accessibilityText(this.colorName(value))
        }, (value: number, index: number) => index.toString())
      }.width('100%').padding(SpacingTokens.sm).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.sm)
      Text($r('app.string.expansion_parking_slots', this.vm.state.tray.length)).fontColor(SemanticColors.textSecondary)
      Row({ space: SpacingTokens.sm }) {
        ForEach(range(3), (slot: number) => {
          Column() {
            if (slot < this.vm.state.tray.length) { this.Bus(this.vm.state.pieces[this.vm.state.tray[slot]]) }
            else { Text('○').fontColor(SemanticColors.textSecondary).height(76).width('100%').textAlign(TextAlign.Center) }
          }.layoutWeight(1).border({ width: 1, color: SemanticColors.border }).borderRadius(RadiusTokens.sm)
        }, (slot: number) => slot.toString())
      }.width('100%')
      if (this.vm.state.tray.length === 3) { Text($r('app.string.expansion_bus_stuck')).fontColor(SemanticColors.warning) }
      Row({ space: SpacingTokens.sm }) {
        ForEach(range(3), (lane: number) => {
          Column({ space: SpacingTokens.sm }) {
            Text($r('app.string.expansion_key', lane + 1)).fontColor(SemanticColors.textSecondary)
            ForEach(range(4), (pos: number) => {
              if (pos >= this.vm.state.data[lane]) {
                Button({ type: ButtonType.Normal }) { this.Bus(this.vm.state.pieces[lane * 4 + pos]) }
                  .width('100%').padding(0).backgroundColor(SemanticColors.surface)
                  .opacity(pos === this.vm.state.data[lane] ? 1 : 0.4)
                  .enabled(pos === this.vm.state.data[lane] && this.vm.state.tray.length < 3)
                  .accessibilityText($r('app.string.expansion_launch_bus', lane + 1, pos + 1))
                  .onClick(() => { this.vm.tap(lane); })
              }
            }, (pos: number) => pos.toString())
          }.layoutWeight(1)
        }, (lane: number) => lane.toString())
      }.width('100%').alignItems(VerticalAlign.Top)
    }.width('100%')
  }
  @Builder
  Yarn() {
    Column({ space: SpacingTokens.base }) {
      Row({ space: SpacingTokens.xs }) {
        ForEach(range(this.vm.state.cols), (col: number) => {
          Button({ type: ButtonType.Normal }) {
            Column({ space: SpacingTokens.xs }) {
              ForEach(range(8), (row: number) => {
                Image(ExpansionArt.yarn(this.vm.state.board[col * 8 + 7 - row] - 1)).width('100%').height(23).objectFit(ImageFit.Fill)
                  .opacity(this.vm.state.board[col * 8 + 7 - row] > 0 ? 1 : 0)
              }, (row: number) => row.toString())
              Text('↓').fontColor(SemanticColors.textPrimary)
            }.width('100%').padding(SpacingTokens.xs)
          }.layoutWeight(1).padding(0).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.sm)
            .accessibilityText($r('app.string.expansion_unwind_column', col + 1)).onClick(() => { this.vm.tap(col); })
        }, (col: number) => col.toString())
      }.width('100%')
      Text($r('app.string.expansion_choose_reel')).fontColor(SemanticColors.textSecondary)
      Row({ space: SpacingTokens.sm }) {
        ForEach(range(3), (reel: number) => {
          Button({ type: ButtonType.Normal }) {
            Column({ space: SpacingTokens.xs }) {
              Image(this.vm.state.tray[reel * 2] > 0 ? ExpansionArt.reel(this.vm.state.tray[reel * 2] - 1) : $r('app.media.exp_empty')).width(50).height(50).objectFit(ImageFit.Contain)
              Text(this.symbol(this.vm.state.tray[reel * 2])).fontColor(this.vm.state.tray[reel * 2] > 0 ? this.color(this.vm.state.tray[reel * 2]) : SemanticColors.textSecondary)
              Text($r('app.string.expansion_capacity', this.vm.state.tray[reel * 2 + 1], 8)).fontColor(SemanticColors.textPrimary)
            }.padding(SpacingTokens.sm)
          }.layoutWeight(1).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.sm)
            .border({ width: this.vm.state.selected === reel ? 2 : 1, color: this.vm.state.selected === reel ? SemanticColors.primary : SemanticColors.border })
            .accessibilityText($r('app.string.expansion_reel', reel + 1)).onClick(() => { this.vm.choose(reel); })
        }, (reel: number) => reel.toString())
      }.width('100%')
    }.width('100%')
  }
  @Builder
  Sand() {
    Column({ space: SpacingTokens.base }) {
      Column({ space: 2 }) {
        ForEach(range(this.vm.state.rows), (row: number) => {
          Row({ space: 2 }) {
            ForEach(range(8), (col: number) => {
              Button({ type: ButtonType.Normal }) {
                Image(ExpansionArt.sand(this.vm.state.board[row * 8 + col] - 1)).width('100%').height('100%').objectFit(ImageFit.Fill)
              }.layoutWeight(1).height('100%').padding(0).backgroundColor(this.color(this.vm.state.board[row * 8 + col]))
                .opacity(this.vm.state.board[row * 8 + col] === 0 ? 0.15 : 1).borderRadius(RadiusTokens.xs)
                .accessibilityText($r('app.string.expansion_cell', row + 1, col + 1, this.symbol(this.vm.state.board[row * 8 + col])))
                .onClick(() => { this.vm.tap(row * 8 + col); })
            }, (col: number) => col.toString())
          }.layoutWeight(1).width('100%')
        }, (row: number) => row.toString())
      }.width('100%').aspectRatio(8 / this.vm.state.rows).padding(SpacingTokens.sm).backgroundColor(SemanticColors.boardBg).backgroundImage(ExpansionArt.board(this.gameId)).backgroundImageSize({ width: '100%', height: '100%' }).borderRadius(RadiusTokens.base)
      Text($r('app.string.expansion_choose_pump')).fontColor(SemanticColors.textSecondary)
      Row({ space: SpacingTokens.xs }) {
        ForEach(this.vm.state.data, (collected: number, color: number) => {
          Button({ type: ButtonType.Normal }) {
            Column({ space: SpacingTokens.xs }) {
              Image(ExpansionArt.nozzle(color)).width(42).height(42).objectFit(ImageFit.Contain)
              Text(this.symbol(color + 1)).fontColor(this.color(color + 1))
              Text($r('app.string.expansion_capacity', collected, 16)).fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textPrimary)
            }.padding(SpacingTokens.xs)
          }.layoutWeight(1).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.sm)
            .border({ width: this.vm.state.selected === color ? 2 : 1, color: this.vm.state.selected === color ? SemanticColors.primary : SemanticColors.border })
            .accessibilityText(this.colorName(color + 1)).onClick(() => { this.vm.choose(color); })
        }, (collected: number, color: number) => color.toString())
      }.width('100%')
    }.width('100%')
  }
  @Builder
  Knots() {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach(range(this.vm.state.board.length / 2), (edge: number) => {
        Line().width('100%').height('100%').startPoint(this.point(this.vm.state.board[edge * 2])).endPoint(this.point(this.vm.state.board[edge * 2 + 1]))
          .strokeWidth(3).stroke(this.vm.crossingEdges().includes(edge * 2) ? SemanticColors.warning : SemanticColors.primary)
          .hitTestBehavior(HitTestMode.None)
      }, (edge: number) => edge.toString())
      ForEach(this.vm.state.pieces, (node: ExpansionPiece) => {
        Text((node.id + 1).toString()).width(36 * this.arenaScale()).height(36 * this.arenaScale()).textAlign(TextAlign.Center)
          .fontSize(FontTokens.sizeBodyLarge).fontColor(SemanticColors.textOnPrimary).backgroundColor(SemanticColors.primary)
          .borderRadius(18 * this.arenaScale()).border({ width: this.vm.state.selected === node.id ? 3 : 0, color: SemanticColors.warning })
          .translate({ x: (node.x - 18) * this.arenaScale(), y: (node.y - 18) * this.arenaScale() })
          .accessibilityText($r('app.string.expansion_node', node.id + 1)).hitTestBehavior(HitTestMode.None)
      }, (node: ExpansionPiece) => node.id.toString())
    }.width('100%').aspectRatio(360 / 460).backgroundColor(SemanticColors.boardBg).backgroundImage(ExpansionArt.board(this.gameId)).backgroundImageSize({ width: '100%', height: '100%' }).borderRadius(RadiusTokens.base)
      .onAreaChange((oldArea: Area, area: Area) => { this.measure(area); }).onTouch((event: TouchEvent) => { this.touch(event); })
  }
}
