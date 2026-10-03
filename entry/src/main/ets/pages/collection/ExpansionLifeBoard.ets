import { ExpansionViewModel } from '../../viewmodel/ExpansionViewModel';
import { ExpansionPiece } from '../../model/game/ExpansionState';
import { SemanticColors, FontTokens, SpacingTokens, RadiusTokens } from '../../common/DesignTokens';
import { range } from '../../common/Range';
import { ExpansionArt } from '../../common/ExpansionArt';
import { GameArtTile } from '../../components/GameArtTile';

@ComponentV2
export struct ExpansionLifeBoard {
  @Param gameId: string = '';
  @Param vm: ExpansionViewModel = new ExpansionViewModel();
  @Local roomWidth: number = 320;
  tool(index: number): Resource {
    const farm: Resource[] = [$r('app.string.expansion_plant'), $r('app.string.expansion_water'), $r('app.string.expansion_harvest')];
    const room: Resource[] = [$r('app.string.expansion_sofa'), $r('app.string.expansion_table'), $r('app.string.expansion_room_plant'), $r('app.string.expansion_lamp'), $r('app.string.expansion_sell')];
    return this.gameId === 'farm' ? farm[index] : room[index];
  }
  roomGlyph(cell: number): string {
    const p: ExpansionPiece | undefined = this.vm.state.pieces.find((piece: ExpansionPiece) => piece.x === cell % 5 && piece.y === Math.floor(cell / 5));
    return p ? ['', '🛋', '▤', '🪴', '💡'][p.color] : '';
  }
  roomArt(cell: number): Resource {
    const piece: ExpansionPiece | undefined = this.vm.state.pieces.find((p: ExpansionPiece) => p.x === cell % 5 && p.y === Math.floor(cell / 5));
    return ExpansionArt.furniture(piece ? piece.color : 0);
  }
  fishingStatus(): Resource { return [$r('app.string.expansion_cast_hint'), $r('app.string.expansion_wait_bite'), $r('app.string.expansion_hook_now'), $r('app.string.expansion_reel_hint')][this.vm.state.data[0]]; }
  hold(event: TouchEvent): void {
    if (event.type === TouchType.Down) { this.vm.setDragging(true); this.vm.tap(1); }
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.vm.tap(2); this.vm.setDragging(false); }
  }
  build() {
    Column({ space: SpacingTokens.base }) {
      if (this.gameId === 'fishing') { this.Fishing() } else {
        Text($r('app.string.expansion_money', this.vm.state.data[0])).fontColor(SemanticColors.textPrimary)
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
          ForEach(range(this.gameId === 'farm' ? 3 : 5), (tool: number) => {
            Button(this.tool(tool)).margin(SpacingTokens.xs).border({ width: this.vm.state.selected === tool ? 2 : 0, color: SemanticColors.warning })
              .onClick(() => { this.vm.choose(tool); })
          }, (tool: number) => tool.toString())
        }.width('100%')
        if (this.gameId === 'farm') { this.Board() } else { this.Room() }
        if (this.gameId === 'farm') {
          Text($r('app.string.expansion_day', this.vm.state.data[1])).fontColor(SemanticColors.textSecondary)
          Button($r('app.string.expansion_next_day')).onClick(() => { this.vm.tap(900); })
        } else {
          ForEach(range(4), (quest: number) => {
            Text(this.quest(quest)).fontColor(this.vm.state.target.length > 0 && this.vm.state.target[quest] === 1 ? SemanticColors.success : SemanticColors.textSecondary)
          }, (quest: number) => quest.toString())
        }
      }
    }.width('100%')
  }
  quest(index: number): Resource { return [$r('app.string.expansion_room_quest_0'), $r('app.string.expansion_room_quest_1'), $r('app.string.expansion_room_quest_2'), $r('app.string.expansion_room_quest_3')][index]; }
  @Builder
  Board() {
    Column({ space: SpacingTokens.xs }) {
      ForEach(range(this.vm.state.rows), (row: number) => {
        Row({ space: SpacingTokens.xs }) {
          ForEach(range(this.vm.state.cols), (col: number) => {
            Column() {
              GameArtTile({ image: this.gameId === 'farm' ? ExpansionArt.farm(this.vm.state.board[row * this.vm.state.cols + col]) : this.roomArt(row * 5 + col),
                description: $r('app.string.expansion_cell', row + 1, col + 1, this.gameId === 'farm' ? ['·', '🌱', '💧', '🌾'][this.vm.state.board[row * this.vm.state.cols + col]] : this.roomGlyph(row * 5 + col)),
                onTap: () => { this.vm.tap(row * this.vm.state.cols + col); } })
            }.layoutWeight(1).height('100%')
          }, (col: number) => col.toString())
        }.width('100%').layoutWeight(1)
      }, (row: number) => row.toString())
    }.width('100%').aspectRatio(1).padding(SpacingTokens.sm).backgroundColor(SemanticColors.boardBg).backgroundImage(ExpansionArt.board(this.gameId)).backgroundImageSize({ width: '100%', height: '100%' }).borderRadius(RadiusTokens.base)
  }
  @Builder
  Room() {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach(range(25), (cell: number) => {
        Column() { GameArtTile({ image: $r('app.media.exp_floor'),
          description: $r('app.string.expansion_cell', Math.floor(cell / 5) + 1, cell % 5 + 1, this.roomGlyph(cell)),
          onTap: () => { this.vm.tap(cell); } }) }.width(this.roomWidth / 5).height(this.roomWidth / 5)
          .translate({ x: cell % 5 * this.roomWidth / 5, y: Math.floor(cell / 5) * this.roomWidth / 5 })
      }, (cell: number) => cell.toString())
      ForEach(this.vm.state.pieces, (piece: ExpansionPiece) => {
        Image(ExpansionArt.furniture(piece.color)).width(piece.w * this.roomWidth / 5).height(piece.h * this.roomWidth / 5).objectFit(ImageFit.Fill)
          .translate({ x: piece.x * this.roomWidth / 5, y: piece.y * this.roomWidth / 5 }).hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      }, (piece: ExpansionPiece) => piece.id.toString())
    }.width('100%').aspectRatio(1).clip(true).borderRadius(RadiusTokens.base)
      .onAreaChange((oldArea: Area, area: Area) => { const width: number = Number(area.width); if (Number.isFinite(width) && width > 0) { this.roomWidth = width; } })
  }
  @Builder
  Fishing() {
    Column({ space: SpacingTokens.base }) {
      Text(this.fishingStatus()).fontSize(FontTokens.sizeSubtitle).fontColor(this.vm.state.data[0] === 2 ? SemanticColors.warning : SemanticColors.textPrimary)
      Stack() {
        Image(ExpansionArt.board('fishing')).width('100%').height('100%').objectFit(ImageFit.Fill).accessibilityLevel('no')
        Image(this.vm.state.data[0] === 2 ? $r('app.media.exp_bite') : this.vm.state.data[0] === 0 ? ExpansionArt.fish(3) : $r('app.media.exp_bobber'))
          .width(62).height(62).objectFit(ImageFit.Contain).accessibilityLevel('no')
          .translate({ x: (this.vm.state.pieces[0].x - 180) * 0.7, y: 30 })
          .scale({ x: this.vm.state.data[0] === 2 ? 1.15 : 1, y: this.vm.state.data[0] === 2 ? 1.15 : 1 })
          .animation({ duration: 180, curve: Curve.FastOutSlowIn })
      }.width('100%').height(180).backgroundColor(SemanticColors.primaryLight).borderRadius(RadiusTokens.base)
      if (this.vm.state.data[0] === 3) {
        Text($r('app.string.expansion_tension', this.vm.state.data[2])).fontColor(SemanticColors.textPrimary)
        Progress({ value: this.vm.state.data[2], total: 100, type: ProgressType.Linear }).color(this.vm.state.data[2] > 80 ? SemanticColors.error : SemanticColors.primary).width('100%')
        Text($r('app.string.expansion_progress', this.vm.state.data[3], 100)).fontColor(SemanticColors.textSecondary)
        Button($r('app.string.expansion_reel_hold')).width('100%').height($r('app.float.expansion_control_height')).onTouch((event: TouchEvent) => { this.hold(event); })
      } else {
        Button(this.vm.state.data[0] === 0 ? $r('app.string.expansion_cast') : $r('app.string.expansion_hook_fish')).enabled(this.vm.state.data[0] !== 1)
          .width('100%').height($r('app.float.expansion_control_height')).onClick(() => { this.vm.tap(0); })
      }
    }.width('100%')
  }
}
