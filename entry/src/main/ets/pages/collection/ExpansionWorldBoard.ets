import { ExpansionViewModel } from '../../viewmodel/ExpansionViewModel';
import { ExpansionRenderPiece } from '../../viewmodel/ExpansionRenderPiece';
import { ExpansionPiece } from '../../model/game/ExpansionState';
import { SemanticColors, FontTokens, SpacingTokens, RadiusTokens } from '../../common/DesignTokens';
import { range } from '../../common/Range';
import { ExpansionArt } from '../../common/ExpansionArt';
import { Haptics } from '../../common/Haptics';
import { HarmonyMotion } from '../../common/HarmonyMotion';
import { resolveString } from '../../common/I18nUtils';

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
          Line().width('100%').height('100%').startPoint(this.roadPoint(i, -1)).endPoint(this.roadPoint(i + 1, -1)).strokeWidth(4).stroke($r('app.color.expansion_road_edge')).hitTestBehavior(HitTestMode.None)
          Line().width('100%').height('100%').startPoint(this.roadPoint(i, 1)).endPoint(this.roadPoint(i + 1, 1)).strokeWidth(4).stroke($r('app.color.expansion_road_edge')).hitTestBehavior(HitTestMode.None)
        }, (i: number) => i.toString())
      }
      ForEach(this.vm.worldPieces, (rendered: ExpansionRenderPiece) => {
        if (rendered.piece.kind === 29) {
          Image($r('app.media.exp_gate')).objectFit(ImageFit.Fill).width(rendered.piece.w * this.arenaScale()).height((rendered.piece.y - rendered.piece.h / 2) * this.arenaScale()).scale({ y: -1 })
            .translate({ x: (rendered.piece.x - rendered.piece.w / 2) * this.arenaScale() }).hitTestBehavior(HitTestMode.None)
          Image($r('app.media.exp_gate')).objectFit(ImageFit.Fill).width(rendered.piece.w * this.arenaScale()).height((460 - rendered.piece.y - rendered.piece.h / 2) * this.arenaScale())
            .translate({ x: (rendered.piece.x - rendered.piece.w / 2) * this.arenaScale(), y: (rendered.piece.y + rendered.piece.h / 2) * this.arenaScale() }).hitTestBehavior(HitTestMode.None)
        } else {
          Image(ExpansionArt.piece(this.gameId, rendered.piece)).width(this.pieceWidth(rendered.piece) * this.arenaScale()).height(this.pieceHeight(rendered.piece) * this.arenaScale())
            .objectFit(rendered.piece.kind === 25 || rendered.piece.kind === 26 || rendered.piece.kind === 39 ? ImageFit.Fill : ImageFit.Contain)
            .rotate({ angle: rendered.piece.kind === 36 && this.gameId === 'hillclimb' ? Math.atan2(this.vm.terrain(rendered.piece.x + 8) - this.vm.terrain(rendered.piece.x - 8), 16) * 180 / Math.PI + 90 : rendered.piece.kind === 33 && this.gameId === 'tanks' ? 180 : 0 })
            .translate({ x: this.pieceX(rendered.piece) * this.arenaScale(), y: this.pieceY(rendered.piece) * this.arenaScale() }).hitTestBehavior(HitTestMode.None)
        }
      }, (rendered: ExpansionRenderPiece) => rendered.id.toString())
      if (this.gameId === 'grapple' && this.vm.state.selected >= 0) {
        ForEach(this.vm.worldPieces.filter((rendered: ExpansionRenderPiece) => rendered.id === this.vm.state.selected), (anchor: ExpansionRenderPiece) => {
          Line().width('100%').height('100%').startPoint([(anchor.piece.x - this.camera()) * this.arenaScale(), anchor.piece.y * this.arenaScale()])
            .endPoint([(this.vm.state.pieces[0].x - this.camera()) * this.arenaScale(), this.vm.state.pieces[0].y * this.arenaScale()])
            .strokeWidth(2).stroke(SemanticColors.primary).hitTestBehavior(HitTestMode.None)
        }, (anchor: ExpansionRenderPiece) => anchor.id.toString())
      }
    }.width('100%').aspectRatio(360 / 460).clip(true).backgroundColor(SemanticColors.boardBg).backgroundImage(ExpansionArt.board(this.gameId)).backgroundImageSize({ width: '100%', height: '100%' }).borderRadius(RadiusTokens.base)
      .onAreaChange((oldArea: Area, area: Area) => { this.measure(area); }).onTouch((event: TouchEvent) => { this.touch(event); })
  }
  @Builder
  Backpack() {
    Column({ space: SpacingTokens.base }) {
      Text($r('app.string.expansion_pack_stats', this.vm.state.data[0], this.vm.state.data[1], this.vm.state.cursor, this.vm.state.goal))
        .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBody).fontColor(SemanticColors.textPrimary)

      Grid() {
        // 直接使用当前棋盘快照；占格值改变时重建对应格子，撤销也立即刷新。
        ForEach(this.vm.state.board, (value: number, index: number) => {
          GridItem() {
            Button({ type: ButtonType.Normal }) {
              Stack() {
                Image($r('app.media.exp_pack_slot')).width('100%').height('100%').objectFit(ImageFit.Contain)
                  .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
                if (value > 0) {
                  Image(ExpansionArt.equipment(value - 1)).width('76%').height('76%').objectFit(ImageFit.Contain)
                    .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
                }
              }.width('100%').height('100%').renderGroup(true)
            }.width('100%').height('100%').padding(0).backgroundColor(Color.Transparent)
              .borderRadius(RadiusTokens.md).enabled(this.vm.state.outcome === 0)
              .clickEffect(HarmonyMotion.press(this.getUIContext()))
              .accessibilityText(this.packCellDescription(index, value))
              .onClick(() => { Haptics.tap(); this.vm.tap(index); })
          }.width('100%').height('100%')
        }, (value: number, index: number) => index.toString() + ':' + value.toString())
      }.width('100%').constraintSize({ maxWidth: $r('app.float.art_backpack_board_max') }).aspectRatio(1)
        .columnsTemplate('1fr 1fr 1fr 1fr').rowsTemplate('1fr 1fr 1fr 1fr')
        .columnsGap(SpacingTokens.xs).rowsGap(SpacingTokens.xs)
        .padding(SpacingTokens.sm).backgroundColor(SemanticColors.boardBg).borderRadius(RadiusTokens.lg)

      Column({ space: SpacingTokens.sm }) {
        Row({ space: SpacingTokens.sm }) {
          ForEach(this.vm.state.tray, (value: number) => {
            Button({ type: ButtonType.Normal }) {
              Image(ExpansionArt.equipment(value - 1)).width('100%').height('100%').objectFit(ImageFit.Contain)
                .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
            }.layoutWeight(1).height($r('app.float.art_backpack_equipment_height')).padding(SpacingTokens.sm)
              .backgroundColor(this.vm.state.selected === value - 1 ? SemanticColors.selectionSurface : SemanticColors.surface)
              .borderRadius(RadiusTokens.md)
              .border({ width: this.vm.state.selected === value - 1 ? $r('app.float.art_backpack_selection_border') : 0,
                color: SemanticColors.primary })
              .enabled(this.vm.state.outcome === 0).clickEffect(HarmonyMotion.press(this.getUIContext()))
              .accessibilityText(this.packInfo(value - 1))
              .accessibilityDescription(this.vm.state.selected === value - 1 ? $r('app.string.settings_selected') : $r('app.string.settings_unselected'))
              .onClick(() => { Haptics.tap(); this.vm.choose(value - 1); })
          }, (value: number) => value.toString() + (this.vm.state.selected === value - 1 ? ':selected' : ':idle'))
        }.width('100%')
        Text(this.packInfo(this.vm.state.selected)).width('100%').textAlign(TextAlign.Center)
          .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBodySmall).fontColor(SemanticColors.textSecondary)
        Row({ space: SpacingTokens.sm }) {
          Button($r('app.string.expansion_fight')).layoutWeight(1)
            .constraintSize({ minHeight: $r('app.float.expansion_control_height') })
            .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBody).fontColor(SemanticColors.textOnPrimary)
            .backgroundColor(SemanticColors.primary).enabled(this.vm.state.outcome === 0)
            .clickEffect(HarmonyMotion.press(this.getUIContext()))
            .onClick(() => { Haptics.tap(); this.vm.tap(100); })
          Button($r('app.string.expansion_undo')).layoutWeight(1)
            .constraintSize({ minHeight: $r('app.float.expansion_control_height') })
            .fontFamily(FontTokens.family).fontSize(FontTokens.sizeBody).fontColor(SemanticColors.textPrimary)
            .backgroundColor(SemanticColors.surface).enabled(this.vm.canUndo)
            .clickEffect(HarmonyMotion.press(this.getUIContext()))
            .onClick(() => { Haptics.tap(); this.vm.undo(); })
        }.width('100%')
      }.width('100%')
    }.width('100%')
  }
  packCellDescription(index: number, value: number): Resource {
    const description: string = resolveString(value > 0 ? this.packInfo(value - 1) : $r('app.string.collection_empty'), this.getUIContext().getHostContext());
    return $r('app.string.expansion_cell', Math.floor(index / 4) + 1, index % 4 + 1, description);
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
        Button($r('app.string.expansion_player', 1)).layoutWeight(1).height($r('app.float.expansion_control_height'))
          .onClick(() => { this.vm.tap(0); })
        Button($r('app.string.expansion_player', 2)).layoutWeight(1).height($r('app.float.expansion_control_height'))
          .onClick(() => { this.vm.tap(1); })
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
