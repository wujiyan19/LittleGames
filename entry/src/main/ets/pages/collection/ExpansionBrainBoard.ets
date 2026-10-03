import { ExpansionViewModel } from '../../viewmodel/ExpansionViewModel';
import { ExpansionPiece } from '../../model/game/ExpansionState';
import { IDIOMS, IDIOM_PARTS } from '../../model/game/ExpansionBrain';
import { ExpansionTonePlayer } from '../../common/ExpansionTonePlayer';
import { SemanticColors, FontTokens, SpacingTokens, RadiusTokens } from '../../common/DesignTokens';
import { range } from '../../common/Range';
import { ExpansionArt } from '../../common/ExpansionArt';
import { GameArtTile } from '../../components/GameArtTile';

@ComponentV2
export struct ExpansionBrainBoard {
  @Param gameId: string = '';
  @Param vm: ExpansionViewModel = new ExpansionViewModel();
  @Local arenaWidth: number = 320;
  @Local audioReady: boolean = false;
  @Local audioFailed: boolean = false;
  private tones: ExpansionTonePlayer = new ExpansionTonePlayer();
  aboutToAppear(): void {
    if (this.gameId === 'melody') {
      this.prepareAudio();
      this.vm.setToneCallbacks((note: number): void => { this.tones.play(note); }, (): void => { this.tones.stop(); });
    }
  }
  prepareAudio(): void {
    this.tones.dispose(); this.tones = new ExpansionTonePlayer(); this.audioReady = false; this.audioFailed = false;
    this.tones.onReady = (ready: boolean): void => { this.audioReady = ready; this.audioFailed = !ready; };
    const context = this.getUIContext().getHostContext(); if (context) { this.tones.init(context.resourceManager); } else { this.audioFailed = true; }
  }
  aboutToDisappear(): void { if (this.gameId === 'melody') { this.vm.setToneCallbacks((note: number): void => {}, (): void => {}); this.tones.dispose(); } }
  arenaScale(): number { return this.arenaWidth / 360; }
  measure(area: Area): void { const width: number = Number(area.width); if (Number.isFinite(width) && width > 0) { this.arenaWidth = width; } }
  point(node: number): number[] { return [(60 + node % 3 * 120) * this.arenaScale(), (100 + Math.floor(node / 3) * 120) * this.arenaScale()]; }
  color(index: number): Resource { return [$r('app.color.expansion_color_1'), $r('app.color.expansion_color_2'), $r('app.color.expansion_color_3'), $r('app.color.expansion_color_4')][index % 4]; }
  object(value: number): string { return ['🌲', '🌷', '🍄', '🦋', '🐈', '🐦', '🪁', '🍎', '🏠'][value - 1]; }
  word(value: number): string { return ['', '木', '火', '水', '金', '森', '焱', '淼', '鑫'][value]; }
  phrase(): string { return IDIOMS[this.vm.state.data[0]].split('').map((v: string, i: number) => i === this.vm.state.data[1] ? '□' : v).join(''); }
  touch(event: TouchEvent): void {
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.vm.setDragging(false); return; } if (event.touches.length === 0) { return; }
    if (event.type === TouchType.Down) { this.vm.setDragging(true); }
    if (this.vm.dragging && (event.type === TouchType.Down || event.type === TouchType.Move)) { this.vm.aim(event.touches[0].x / this.arenaScale(), event.touches[0].y / this.arenaScale()); }
  }
  build() {
    Column({ space: SpacingTokens.base }) {
      if (this.gameId === 'onestroke') { this.Stroke() }
      if (this.gameId === 'hiddenobjects') { this.Hidden() }
      if (this.gameId === 'picturepuzzle') { this.Picture() }
      if (this.gameId === 'idiom') { this.Idiom() }
      if (this.gameId === 'linerescue' || this.gameId === 'wordtower' || this.gameId === 'beatjump') { this.Arena() }
      if (this.gameId === 'melody') { this.Melody() }
      if (['linerescue', 'wordtower', 'beatjump'].includes(this.gameId) && this.vm.state.phase === 0) { Button($r('app.string.expansion_ready')).onClick(() => { this.vm.activate(); }) }
      if (this.gameId === 'linerescue' && this.vm.state.phase === 0) { Button($r('app.string.expansion_clear_line')).onClick(() => { this.vm.tap(900); }) }
      if (this.gameId === 'wordtower') {
        Text($r('app.string.expansion_pack_stats', this.vm.state.data[0], this.vm.state.data[1], this.vm.state.moves, this.vm.state.goal)).fontColor(SemanticColors.textPrimary)
        Text($r('app.string.expansion_tower_cost')).fontColor(SemanticColors.textSecondary)
        Row({ space: SpacingTokens.sm }) { ForEach(range(4), (i: number) => { Button(this.word(i + 1)).layoutWeight(1).border({ width: this.vm.state.next === i + 1 ? 3 : 0, color: SemanticColors.warning }).onClick(() => { this.vm.choose(i); }) }, (i: number) => i.toString()) }.width('100%')
      }
      if (this.gameId === 'beatjump') {
        Text($r('app.string.expansion_beat_time', Math.max(0, Math.round(this.vm.state.cooldown * 1000)))).fontColor(SemanticColors.textSecondary)
        Text(this.vm.state.target.slice(this.vm.state.cursor, this.vm.state.cursor + 4).map((v: number) => ['←', '●', '→'][v]).join('   ')).fontSize(FontTokens.sizeTitle).fontColor(SemanticColors.primary)
        Row({ space: SpacingTokens.sm }) { ForEach(range(3), (lane: number) => { Button(['←', '●', '→'][lane]).layoutWeight(1).height($r('app.float.expansion_control_height')).onClick(() => { this.vm.tap(lane); }) }, (lane: number) => lane.toString()) }.width('100%')
      }
    }.width('100%').padding(SpacingTokens.sm).backgroundImage(ExpansionArt.board(this.gameId)).backgroundImageSize({ width: '100%', height: '100%' }).borderRadius(RadiusTokens.base)
  }
  @Builder
  Stroke() {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach(range(this.vm.state.goal), (edge: number) => {
        Line().width('100%').height('100%').startPoint(this.point(this.vm.state.board[edge * 2])).endPoint(this.point(this.vm.state.board[edge * 2 + 1]))
          .strokeWidth(this.vm.state.tray.includes(edge) ? 5 : 2).stroke(this.vm.state.tray.includes(edge) ? SemanticColors.primary : SemanticColors.border).hitTestBehavior(HitTestMode.None)
      }, (edge: number) => edge.toString())
      ForEach(range(9), (node: number) => {
        Button((node + 1).toString(), { type: ButtonType.Circle }).width(38 * this.arenaScale()).height(38 * this.arenaScale()).padding(0)
          .backgroundColor(this.vm.state.selected === node ? SemanticColors.warning : SemanticColors.primary)
          .translate({ x: this.point(node)[0] - 19 * this.arenaScale(), y: this.point(node)[1] - 19 * this.arenaScale() }).onClick(() => { this.vm.tap(node); })
      }, (node: number) => node.toString())
    }.width('100%').aspectRatio(360 / 460).backgroundColor(SemanticColors.boardBg).backgroundImage(ExpansionArt.board(this.gameId)).backgroundImageSize({ width: '100%', height: '100%' }).borderRadius(RadiusTokens.base).onAreaChange((oldArea: Area, area: Area) => { this.measure(area); })
  }
  @Builder
  Hidden() {
    Column({ space: SpacingTokens.sm }) {
      Text($r('app.string.expansion_find_objects')).fontColor(SemanticColors.textSecondary)
      Row({ space: SpacingTokens.xs }) { ForEach(this.vm.state.target, (value: number) => { Image(this.hiddenArt(value)).objectFit(ImageFit.Contain).height(42).layoutWeight(1).opacity(this.vm.state.tray.includes(value) ? 0.2 : 1).accessibilityText(this.object(value)) }, (value: number) => value.toString()) }.width('100%')
      Column({ space: SpacingTokens.xs }) {
        ForEach(range(6), (row: number) => {
          Row({ space: SpacingTokens.xs }) {
            ForEach(range(6), (col: number) => {
              Column() { GameArtTile({ image: this.hiddenArt(this.vm.state.board[row * 6 + col]), description: this.object(this.vm.state.board[row * 6 + col]),
                onTap: () => { this.vm.tap(row * 6 + col); } }) }.layoutWeight(1).height('100%')
            }, (col: number) => col.toString())
          }.layoutWeight(1).width('100%')
        }, (row: number) => row.toString())
      }.width('100%').aspectRatio(1).padding(SpacingTokens.sm).backgroundColor(SemanticColors.boardBg).backgroundImage(ExpansionArt.board(this.gameId)).backgroundImageSize({ width: '100%', height: '100%' }).borderRadius(RadiusTokens.base)
    }.width('100%')
  }
  @Builder
  Picture() {
    Column({ space: SpacingTokens.sm }) {
      Image($r('app.media.expansion_puzzle_scene')).width('35%').aspectRatio(1).objectFit(ImageFit.Fill).borderRadius(RadiusTokens.sm)
      Column({ space: 0 }) {
        ForEach(range(this.vm.state.rows), (row: number) => {
          Row({ space: 0 }) {
            ForEach(range(this.vm.state.cols), (col: number) => {
              Stack({ alignContent: Alignment.TopStart }) {
                Image($r('app.media.expansion_puzzle_scene')).width(this.arenaWidth).height(this.arenaWidth).objectFit(ImageFit.Fill)
                  .translate({ x: -(this.vm.state.board[row * this.vm.state.cols + col] % this.vm.state.cols) * this.arenaWidth / this.vm.state.cols,
                    y: -Math.floor(this.vm.state.board[row * this.vm.state.cols + col] / this.vm.state.cols) * this.arenaWidth / this.vm.state.cols }).hitTestBehavior(HitTestMode.None)
              }.width(this.arenaWidth / this.vm.state.cols).height(this.arenaWidth / this.vm.state.cols).clip(true)
                .border({ width: this.vm.state.selected === row * this.vm.state.cols + col ? 3 : 1, color: this.vm.state.selected === row * this.vm.state.cols + col ? SemanticColors.primary : SemanticColors.surface })
                .onClick(() => { this.vm.tap(row * this.vm.state.cols + col); })
            }, (col: number) => col.toString())
          }.width('100%')
        }, (row: number) => row.toString())
      }.width('100%').aspectRatio(1).onAreaChange((oldArea: Area, area: Area) => { this.measure(area); })
    }.width('100%')
  }
  @Builder
  Idiom() {
    Column({ space: SpacingTokens.base }) {
      Text(this.phrase()).fontSize(FontTokens.sizeDisplay).fontColor(SemanticColors.textPrimary).padding(SpacingTokens.xl)
      Row({ space: SpacingTokens.sm }) {
        ForEach(this.vm.state.board, (part: number, index: number) => { Button(IDIOM_PARTS[part]).layoutWeight(1).height(64).fontSize(FontTokens.sizeTitle).onClick(() => { this.vm.tap(index); }) }, (part: number) => part.toString())
      }.width('100%')
    }.width('100%')
  }
  @Builder
  Arena() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.gameId === 'linerescue') {
        ForEach(range(Math.max(0, this.vm.state.target.length / 2 - 1)), (segment: number) => {
          Line().width('100%').height('100%').startPoint([this.vm.state.target[segment * 2] * this.arenaScale(), this.vm.state.target[segment * 2 + 1] * this.arenaScale()])
            .endPoint([this.vm.state.target[segment * 2 + 2] * this.arenaScale(), this.vm.state.target[segment * 2 + 3] * this.arenaScale()]).strokeWidth(5).stroke(SemanticColors.primary).hitTestBehavior(HitTestMode.None)
        }, (segment: number) => segment.toString())
      }
      if (this.gameId === 'wordtower') {
        ForEach(range(6), (slot: number) => {
          Button(this.word(this.vm.state.board[slot]), { type: ButtonType.Normal }).width(60 * this.arenaScale()).height(60 * this.arenaScale()).padding(0)
            .fontSize(FontTokens.sizeTitle).backgroundColor(SemanticColors.surface).fontColor(SemanticColors.primary)
            .border({ width: this.vm.state.tray.includes(slot) ? 3 : 1, color: SemanticColors.primary })
            .translate({ x: (40 + slot % 3 * 110) * this.arenaScale(), y: (260 + Math.floor(slot / 3) * 95) * this.arenaScale() }).onClick(() => { this.vm.tap(slot); })
        }, (slot: number) => slot.toString())
      }
      if (this.gameId === 'beatjump') { ForEach(range(3), (lane: number) => { Column().width(72 * this.arenaScale()).height(18 * this.arenaScale()).backgroundColor(this.color(lane)).translate({ x: (24 + lane * 120) * this.arenaScale(), y: 370 * this.arenaScale() }) }, (lane: number) => lane.toString()) }
      ForEach(this.vm.state.pieces.filter((p: ExpansionPiece) => p.kind !== 57), (p: ExpansionPiece) => {
        Image(ExpansionArt.piece(this.gameId, p)).width(p.r * 2 * this.arenaScale()).height(p.r * 2 * this.arenaScale()).objectFit(ImageFit.Contain)
          .translate({ x: (p.x - p.r) * this.arenaScale(), y: (p.y - p.r) * this.arenaScale() }).hitTestBehavior(HitTestMode.None)
      }, (p: ExpansionPiece) => p.id.toString())
    }.width('100%').aspectRatio(360 / 460).clip(true).backgroundColor(SemanticColors.boardBg).backgroundImage(ExpansionArt.board(this.gameId)).backgroundImageSize({ width: '100%', height: '100%' }).borderRadius(RadiusTokens.base)
      .onAreaChange((oldArea: Area, area: Area) => { this.measure(area); }).onTouch((event: TouchEvent) => { if (this.gameId === 'linerescue') { this.touch(event); } })
  }
  @Builder
  Melody() {
    Column({ space: SpacingTokens.base }) {
      Text(this.vm.state.phase === 1 ? $r('app.string.expansion_listen') : $r('app.string.expansion_repeat_melody')).fontColor(SemanticColors.textPrimary)
      Row({ space: SpacingTokens.sm }) {
        ForEach(range(4), (note: number) => {
          Button(['C', 'D', 'E', 'G'][note], { type: ButtonType.Normal }).layoutWeight(1).height(130).fontSize(FontTokens.sizeTitle)
            .backgroundColor(this.color(note)).opacity(this.vm.state.selected === note ? 1 : 0.45).borderRadius(RadiusTokens.base)
            .scale({ x: this.vm.state.selected === note ? 1.03 : 1, y: this.vm.state.selected === note ? 1.03 : 1 })
            .animation({ duration: 150, curve: Curve.FastOutSlowIn })
            .backgroundImage(ExpansionArt.block(note)).backgroundImageSize(ImageSize.Cover)
            .enabled(this.vm.state.phase === 0 && this.audioReady).onClick(() => { this.vm.tap(note); })
        }, (note: number) => note.toString())
      }.width('100%')
      if (this.audioFailed) { Button($r('app.string.expansion_audio_retry')).onClick(() => { this.prepareAudio(); }) }
      else if (!this.audioReady) { Text($r('app.string.expansion_audio_loading')).fontColor(SemanticColors.textSecondary) }
      Button($r('app.string.expansion_play_melody')).enabled(this.vm.state.phase === 0 && this.audioReady).onClick(() => { this.vm.tap(900); })
    }.width('100%')
  }
  hiddenArt(value: number): Resource {
    return value === 8 ? ExpansionArt.fruit(4) : value === 9 ? ExpansionArt.object(2) : ExpansionArt.object([0, 1, 3, 5, 6, 7, 8][value - 1]);
  }
}
