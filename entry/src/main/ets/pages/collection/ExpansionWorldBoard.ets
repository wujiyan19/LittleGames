import { ExpansionViewModel } from '../../viewmodel/ExpansionViewModel';
import { ExpansionPiece } from '../../model/game/ExpansionState';
import { SemanticColors, FontTokens, SpacingTokens, RadiusTokens } from '../../common/DesignTokens';
import { range } from '../../common/Range';
import { ExpansionArt } from '../../common/ExpansionArt';
import { GameArtTile } from '../../components/GameArtTile';

@ComponentV2
export struct ExpansionWorldBoard {
  @Param gameId: string = '';
  @Param vm: ExpansionViewModel = new ExpansionViewModel();
  @Local arenaWidth: number = 320;
  arenaScale(): number { return this.arenaWidth / 360; }
  camera(): number { return ['platformer', 'grapple', 'hillclimb'].includes(this.gameId) ? Math.max(0, this.vm.state.pieces[0].x - 160) : 0; }
  measure(area: Area): void { const width: number = Number(area.width); if (Number.isFinite(width) && width > 0) { this.arenaWidth = width; } }
  glyph(p: ExpansionPiece): string {
    if (p.kind === 24) { return ['shooter', 'tanks', 'fortress'].includes(this.gameId) ? (this.gameId === 'shooter' ? '✈' : '▣') : '●'; }
    if (p.kind === 27) { return '⚑'; } if (p.kind === 28) { return '⊙'; } if (p.kind === 30) { return ['🍒', '🍊', '🍎', '🍐', '🍑', '🍓'][(p.color - 1) % 6]; }
    if (p.kind === 31) { return this.gameId === 'fruitslice' ? '💣' : '●'; } if (p.kind === 33) { return this.gameId === 'tanks' ? '▣' : '👾'; }
    if (p.kind === 36) { return '🚙'; } if (p.kind === 37) { return '♟'; } if (p.kind === 43) { return '⚑'; } if (p.kind === 44) { return '🧤'; }
    return '';
  }
  pieceColor(p: ExpansionPiece): Resource {
    if (p.kind === 42 || p.kind === 31) { return SemanticColors.textPrimary; }
    if (p.kind === 25 || p.kind === 26 || p.kind === 37) { return SemanticColors.border; }
    if (p.kind === 33 || p.owner === 1) { return SemanticColors.error; }
    if (p.kind === 27 || p.kind === 43) { return SemanticColors.success; }
    const colors: Resource[] = [$r('app.color.expansion_color_1'), $r('app.color.expansion_color_2'), $r('app.color.expansion_color_3'),
      $r('app.color.expansion_color_4'), $r('app.color.expansion_color_5'), $r('app.color.expansion_color_6')];
    return p.color > 0 ? colors[(p.color - 1) % 6] : SemanticColors.primary;
  }
  pieceWidth(p: ExpansionPiece): number { return p.kind === 25 || p.kind === 26 || (p.kind === 39 && p.r === 0) ? p.w : p.r * 2; }
  pieceHeight(p: ExpansionPiece): number { return p.kind === 25 || p.kind === 26 || (p.kind === 39 && p.r === 0) ? p.h : p.r * 2; }
  pieceX(p: ExpansionPiece): number { return (p.kind === 25 || p.kind === 26 ? p.x : p.x - this.pieceWidth(p) / 2) - this.camera(); }
  pieceY(p: ExpansionPiece): number { return p.kind === 25 || p.kind === 26 ? p.y : p.y - this.pieceHeight(p) / 2; }
  terrainPoint(i: number): number[] { const x: number = i * 24; return [x * this.arenaScale(), this.vm.terrain(x + this.camera()) * this.arenaScale()]; }
  roadPoint(i: number, side: number): number[] { const y: number = i * 46; const center: number = 180 + Math.sin((this.vm.state.time + (390 - y) / 100) * 0.65) * 90; return [(center + side * 65) * this.arenaScale(), y * this.arenaScale()]; }
  touch(event: TouchEvent): void {
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.vm.setDragging(false); return; }
    if (event.touches.length === 0) { return; }
    if (event.type === TouchType.Down) { this.vm.setDragging(true); }
    if (event.type === TouchType.Down || (event.type === TouchType.Move && this.vm.dragging && ['fruitslice', 'rollingball', 'shooter', 'tanks', 'survival', 'pingpong', 'airhockey'].includes(this.gameId))) {
      this.vm.aim(event.touches[0].x / this.arenaScale(), event.touches[0].y / this.arenaScale());
    }
  }
  hold(event: TouchEvent, command: number, release: number): void {
    if (event.type === TouchType.Down) { this.vm.setDragging(true); this.vm.tap(command); }
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.vm.tap(release); this.vm.setDragging(false); }
  }
  build() {
    Column({ space: SpacingTokens.base }) {
      if (this.gameId === 'backpack') { this.Backpack() } else if (this.gameId === 'dots') { this.Dots() }
      else if (this.gameId === 'tug') { this.Tug() } else {
        this.Arena()
        if (this.vm.state.phase === 0 && !['billiards', 'golf', 'bowling'].includes(this.gameId)) {
          Button($r('app.string.expansion_ready')).onClick(() => { this.vm.activate(); })
        }
        if (this.gameId === 'platformer') {
          Row({ space: SpacingTokens.sm }) {
            Button('←').layoutWeight(1).height($r('app.float.expansion_control_height')).accessibilityText($r('app.string.expansion_left'))
              .onTouch((event: TouchEvent) => { this.hold(event, 0, 3); })
            Button($r('app.string.expansion_jump')).layoutWeight(1).height($r('app.float.expansion_control_height')).onClick(() => { this.vm.tap(2); })
            Button('→').layoutWeight(1).height($r('app.float.expansion_control_height')).accessibilityText($r('app.string.expansion_right'))
              .onTouch((event: TouchEvent) => { this.hold(event, 1, 3); })
          }.width('100%')
        }
        if (this.gameId === 'grapple') {
          Row({ space: SpacingTokens.sm }) {
            Button($r('app.string.expansion_hook')).layoutWeight(1).onClick(() => { this.vm.tap(0); })
            Button($r('app.string.expansion_release')).layoutWeight(1).onClick(() => { this.vm.tap(1); })
          }.width('100%')
        }
        if (this.gameId === 'flappy') { Button($r('app.string.expansion_flap')).height($r('app.float.expansion_control_height')).width('100%').onClick(() => { this.vm.tap(0); }) }
        if (this.gameId === 'fortress') { Button($r('app.string.expansion_upgrade')).onClick(() => { this.vm.tap(0); }) }
        if (this.gameId === 'drift') { Button($r('app.string.expansion_drift')).width('100%').height($r('app.float.expansion_control_height')).onClick(() => { this.vm.tap(0); }) }
        if (this.gameId === 'hillclimb') {
          Row({ space: SpacingTokens.sm }) {
            Button($r('app.string.expansion_brake')).layoutWeight(1).height($r('app.float.expansion_control_height')).onTouch((event: TouchEvent) => { this.hold(event, 1, 2); })
            Button($r('app.string.expansion_gas')).layoutWeight(1).height($r('app.float.expansion_control_height')).onTouch((event: TouchEvent) => { this.hold(event, 0, 2); })
          }.width('100%')
        }
      }
    }.width('100%')
  }
  @Builder
  Arena() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.gameId === 'pingpong' || this.gameId === 'airhockey') { Line().width('100%').height('100%').startPoint([0, 230 * this.arenaScale()]).endPoint([this.arenaWidth, 230 * this.arenaScale()]).strokeWidth(2).stroke(SemanticColors.border).hitTestBehavior(HitTestMode.None) }
      if (this.gameId === 'penalty') { Line().width('100%').height('100%').startPoint([30 * this.arenaScale(), 95 * this.arenaScale()]).endPoint([330 * this.arenaScale(), 95 * this.arenaScale()]).strokeWidth(4).stroke(SemanticColors.success).hitTestBehavior(HitTestMode.None) }
      if (this.gameId === 'hillclimb') {
        ForEach(range(15), (i: number) => { Line().width('100%').height('100%').startPoint(this.terrainPoint(i)).endPoint(this.terrainPoint(i + 1)).strokeWidth(4).stroke(SemanticColors.success).hitTestBehavior(HitTestMode.None) }, (i: number) => i.toString())
      }
      if (this.gameId === 'drift') {
        ForEach(range(10), (i: number) => {
          Line().width('100%').height('100%').startPoint(this.roadPoint(i, -1)).endPoint(this.roadPoint(i + 1, -1)).strokeWidth(4).stroke(SemanticColors.border).hitTestBehavior(HitTestMode.None)
          Line().width('100%').height('100%').startPoint(this.roadPoint(i, 1)).endPoint(this.roadPoint(i + 1, 1)).strokeWidth(4).stroke(SemanticColors.border).hitTestBehavior(HitTestMode.None)
        }, (i: number) => i.toString())
      }
      ForEach(this.vm.state.pieces, (p: ExpansionPiece) => {
        if (p.kind === 29) {
          Image($r('app.media.exp_gate')).objectFit(ImageFit.Fill).width(p.w * this.arenaScale()).height((p.y - p.h / 2) * this.arenaScale()).scale({ y: -1 })
            .translate({ x: (p.x - p.w / 2) * this.arenaScale() }).hitTestBehavior(HitTestMode.None)
          Image($r('app.media.exp_gate')).objectFit(ImageFit.Fill).width(p.w * this.arenaScale()).height((460 - p.y - p.h / 2) * this.arenaScale())
            .translate({ x: (p.x - p.w / 2) * this.arenaScale(), y: (p.y + p.h / 2) * this.arenaScale() }).hitTestBehavior(HitTestMode.None)
        } else {
          Image(ExpansionArt.piece(this.gameId, p)).width(this.pieceWidth(p) * this.arenaScale()).height(this.pieceHeight(p) * this.arenaScale())
            .objectFit(p.kind === 25 || p.kind === 26 || p.kind === 39 ? ImageFit.Fill : ImageFit.Contain)
            .rotate({ angle: p.kind === 36 && this.gameId === 'hillclimb' ? Math.atan2(this.vm.terrain(p.x + 8) - this.vm.terrain(p.x - 8), 16) * 180 / Math.PI + 90 : p.kind === 33 && this.gameId === 'tanks' ? 180 : 0 })
            .translate({ x: this.pieceX(p) * this.arenaScale(), y: this.pieceY(p) * this.arenaScale() }).hitTestBehavior(HitTestMode.None)
        }
      }, (p: ExpansionPiece) => p.id.toString())
      if (this.gameId === 'grapple' && this.vm.state.selected >= 0) {
        ForEach(this.vm.state.pieces.filter((p: ExpansionPiece) => p.id === this.vm.state.selected), (anchor: ExpansionPiece) => {
          Line().width('100%').height('100%').startPoint([(anchor.x - this.camera()) * this.arenaScale(), anchor.y * this.arenaScale()])
            .endPoint([(this.vm.state.pieces[0].x - this.camera()) * this.arenaScale(), this.vm.state.pieces[0].y * this.arenaScale()])
            .strokeWidth(2).stroke(SemanticColors.primary).hitTestBehavior(HitTestMode.None)
        }, (anchor: ExpansionPiece) => anchor.id.toString())
      }
    }.width('100%').aspectRatio(360 / 460).clip(true).backgroundColor(SemanticColors.boardBg).backgroundImage(ExpansionArt.board(this.gameId)).backgroundImageSize({ width: '100%', height: '100%' }).borderRadius(RadiusTokens.base)
      .onAreaChange((oldArea: Area, area: Area) => { this.measure(area); }).onTouch((event: TouchEvent) => { this.touch(event); })
  }
  @Builder
  Backpack() {
    Column({ space: SpacingTokens.base }) {
      Text($r('app.string.expansion_pack_stats', this.vm.state.data[0], this.vm.state.data[1], this.vm.state.cursor, this.vm.state.goal)).fontColor(SemanticColors.textPrimary)
      Row({ space: SpacingTokens.xs }) {
        ForEach(range(4), (item: number) => {
          Column() { GameArtTile({ image: ExpansionArt.equipment(item), description: this.packInfo(item), selected: this.vm.state.selected === item, onTap: () => { this.vm.choose(item); } }) }
            .layoutWeight(1).height($r('app.float.expansion_control_height'))
        }, (item: number) => item.toString())
      }.width('100%')
      Text(this.packInfo(this.vm.state.selected)).fontColor(SemanticColors.textSecondary)
      Column({ space: SpacingTokens.xs }) {
        ForEach(range(4), (row: number) => {
          Row({ space: SpacingTokens.xs }) {
            ForEach(range(4), (col: number) => {
              Column() { GameArtTile({ image: this.vm.state.board[row * 4 + col] === 0 ? $r('app.media.exp_empty') : ExpansionArt.equipment(this.vm.state.board[row * 4 + col] - 1),
                description: $r('app.string.expansion_cell', row + 1, col + 1, ['','⚔','⛨','✚','♞'][this.vm.state.board[row * 4 + col]]), onTap: () => { this.vm.tap(row * 4 + col); } }) }.layoutWeight(1).height('100%')
            }, (col: number) => col.toString())
          }.layoutWeight(1).width('100%')
        }, (row: number) => row.toString())
      }.width('100%').aspectRatio(1)
      Button($r('app.string.expansion_fight')).onClick(() => { this.vm.tap(100); })
    }.width('100%')
  }
  packInfo(item: number): Resource {
    return [$r('app.string.expansion_pack_sword'), $r('app.string.expansion_pack_shield'), $r('app.string.expansion_pack_potion'), $r('app.string.expansion_pack_boots')][Math.max(0, Math.min(3, item))];
  }
  @Builder
  Tug() {
    Column({ space: SpacingTokens.base }) {
      Text($r('app.string.expansion_tug_position', this.vm.state.data[0])).fontColor(SemanticColors.textPrimary)
      Stack() {
        Image(ExpansionArt.board('tug')).width('100%').height('100%').objectFit(ImageFit.Fill).accessibilityLevel('no')
        Row() {
          Image(ExpansionArt.person(0)).width($r('app.float.art_tug_character')).height($r('app.float.art_tug_character')).objectFit(ImageFit.Contain)
          Line().layoutWeight(1).height(3).startPoint([0, 1]).endPoint([160, 1]).strokeWidth(3).stroke(SemanticColors.warning)
          Image(ExpansionArt.person(1)).width($r('app.float.art_tug_character')).height($r('app.float.art_tug_character')).objectFit(ImageFit.Contain)
        }.width('90%').translate({ x: (this.vm.state.data[0] - 50) * 0.7 }).animation({ duration: 120 })
      }.width('100%').height($r('app.float.art_banner_height')).clip(true).borderRadius(RadiusTokens.base).hitTestBehavior(HitTestMode.None)
      Progress({ value: this.vm.state.data[0], total: 100, type: ProgressType.Linear }).width('100%').color(SemanticColors.primary)
      Row({ space: SpacingTokens.sm }) {
        Button($r('app.string.expansion_player', 1)).layoutWeight(1).height($r('app.float.expansion_control_height')).onClick(() => { this.vm.tap(0); })
        Button($r('app.string.expansion_player', 2)).layoutWeight(1).height($r('app.float.expansion_control_height')).onClick(() => { this.vm.tap(1); })
      }.width('100%')
    }.width('100%')
  }
  @Builder
  Dots() {
    Column({ space: SpacingTokens.xs }) {
      Text($r('app.string.expansion_turn', this.vm.state.cursor + 1)).fontColor(SemanticColors.textPrimary)
      ForEach(range(this.vm.state.rows + 1), (row: number) => {
        Row({ space: 0 }) {
          ForEach(range(this.vm.state.cols), (col: number) => {
            Text('●').fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textPrimary)
            Button('━', { type: ButtonType.Normal }).layoutWeight(1).height(26).padding(0)
              .fontColor(this.vm.state.board[row * this.vm.state.cols + col] === 0 ? SemanticColors.border : this.vm.state.board[row * this.vm.state.cols + col] === 1 ? SemanticColors.primary : SemanticColors.error)
              .backgroundColor(SemanticColors.boardBg).onClick(() => { this.vm.tap(row * this.vm.state.cols + col); })
          }, (col: number) => col.toString())
          Text('●').fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textPrimary)
        }.width('100%')
        if (row < this.vm.state.rows) {
          Row({ space: 0 }) {
            ForEach(range(this.vm.state.cols + 1), (col: number) => {
              Button('┃', { type: ButtonType.Normal }).width(20).height(48).padding(0).backgroundColor(SemanticColors.boardBg)
                .fontColor(this.vm.state.board[this.vm.state.cols * (this.vm.state.cols + 1) + row * (this.vm.state.cols + 1) + col] === 0 ? SemanticColors.border : this.vm.state.board[this.vm.state.cols * (this.vm.state.cols + 1) + row * (this.vm.state.cols + 1) + col] === 1 ? SemanticColors.primary : SemanticColors.error)
                .onClick(() => { this.vm.tap(this.vm.state.cols * (this.vm.state.cols + 1) + row * (this.vm.state.cols + 1) + col); })
              if (col < this.vm.state.cols) { Text(this.vm.state.data[row * this.vm.state.cols + col] === 0 ? '' : this.vm.state.data[row * this.vm.state.cols + col].toString()).layoutWeight(1).textAlign(TextAlign.Center).fontColor(SemanticColors.primary) }
            }, (col: number) => col.toString())
          }.width('100%')
        }
      }, (row: number) => row.toString())
    }.width('100%').padding(SpacingTokens.sm).backgroundColor(SemanticColors.boardBg).backgroundImage(ExpansionArt.board(this.gameId)).backgroundImageSize({ width: '100%', height: '100%' }).borderRadius(RadiusTokens.base)
  }
}
