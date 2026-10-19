import { ExpansionViewModel } from '../viewmodel/ExpansionViewModel';
import { ExpansionRenderPiece } from '../viewmodel/ExpansionRenderPiece';
import { ExpansionPiece } from '../model/game/ExpansionState';
import { ExpansionScrews } from '../model/game/ExpansionScrews';
import { SemanticColors, FontTokens, SpacingTokens, RadiusTokens } from '../common/DesignTokens';
import { HarmonyMotion } from '../common/HarmonyMotion';
import { Haptics } from '../common/Haptics';
import { range } from '../common/Range';

/** Keep the color reactive when ForEach retains a screw across different deals. */
@ComponentV2
struct ToyScrewHead {
  @Param color: number = 1;
  colorResource(): Resource {
    const colors: Resource[] = [$r('app.color.toy_screw_coral'), $r('app.color.toy_screw_gold'),
      $r('app.color.toy_screw_mint'), $r('app.color.toy_screw_blue'), $r('app.color.toy_screw_lilac')];
    return colors[(this.color - 1) % colors.length];
  }
  build() {
    Stack({ alignContent: Alignment.Center }) {
      Stack() {}.width('94%').height('94%').backgroundColor(this.colorResource()).borderRadius(RadiusTokens.full)
      Image($r('app.media.toy_screw')).width('72%').height('72%').objectFit(ImageFit.Contain)
      Text(this.color.toString()).fontSize(FontTokens.sizeCaption).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.toy_direction_ink')).backgroundColor(this.colorResource())
        .borderRadius(SpacingTokens.xs).padding({ left: 2, right: 2 }).align(Alignment.BottomEnd)
    }.width('100%').height('100%').hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
  }
}

/** Fixed top view; original model sprites share the gameplay geometry and hit rectangles. */
@ComponentV2
export struct ToyPuzzleBoard {
  @Param vm: ExpansionViewModel = new ExpansionViewModel();
  @Param parking: boolean = false;
  @Param boardHeightLimit: number = 460;
  @Local widthVp: number = 320;
  @Local availableWidth: number = 320;
  unit(): number { return this.widthVp / 360; }
  arrow(direction: number): string { return ['↑', '→', '↓', '←'][direction]; }
  plate(color: number): Resource {
    const images: Resource[] = [$r('app.media.toy_plate_0'), $r('app.media.toy_plate_1'), $r('app.media.toy_plate_2'),
      $r('app.media.toy_plate_3'), $r('app.media.toy_plate_4')];
    return images[(color - 1) % images.length];
  }
  car(id: number): Resource {
    const images: Resource[] = [$r('app.media.toy_car_0'), $r('app.media.toy_car_1'), $r('app.media.toy_car_2'),
      $r('app.media.toy_car_3'), $r('app.media.toy_car_4'), $r('app.media.toy_car_5')];
    return images[id % images.length];
  }
  screwFree(screw: ExpansionPiece): boolean {
    return ExpansionScrews.free(this.vm.state, screw);
  }
  trayScrew(slot: number): ExpansionPiece | undefined {
    return this.vm.state.pieces.find((p: ExpansionPiece) => p.id === this.vm.state.tray[slot]);
  }
  carWidth(p: ExpansionPiece): number { return p.w * this.widthVp / this.vm.state.cols - 4; }
  carHeight(p: ExpansionPiece): number { return p.h * this.widthVp / this.vm.state.rows - 4; }
  tap(id: number): void {
    Haptics.tap();
    this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut }, () => { this.vm.tap(id); });
  }

  @Builder
  ScrewTray() {
    Column({ space: SpacingTokens.xs }) {
      if (this.vm.state.phase === 1) {
        Text($r('app.string.toy_screw_tray_count', this.vm.state.tray.length, ExpansionScrews.capacity(this.vm.state)))
          .fontSize(FontTokens.sizeCaption).fontColor(SemanticColors.textPrimary).id('toy-screw-tray-count')
      }
      Row({ space: SpacingTokens.xs }) {
        ForEach(range(ExpansionScrews.capacity(this.vm.state)), (slot: number) => {
          Stack() {
            Image($r('app.media.toy_slot')).width('100%').height('100%').accessibilityLevel('no')
            if (this.vm.state.tray[slot] !== undefined) {
              if (this.vm.state.phase === 1) {
                ToyScrewHead({ color: this.trayScrew(slot)?.color ?? 1 })
              } else {
                Image($r('app.media.toy_screw')).width('86%').height('86%').accessibilityLevel('no')
              }
            }
          }.width($r('app.float.toy_tray_slot_size')).height($r('app.float.toy_tray_slot_size'))
            .accessibilityText(this.trayScrew(slot) === undefined ? $r('app.string.toy_screw_slot', slot + 1) :
              $r('app.string.toy_screw_slot_color', slot + 1, this.trayScrew(slot)?.color ?? 1))
            .id('toy-screw-slot-' + slot)
        }, (slot: number) => slot.toString())
      }.padding(SpacingTokens.sm).backgroundColor($r('app.color.toy_tray_background'))
        .borderRadius($r('app.float.toy_board_radius')).renderGroup(true)
      if (this.vm.state.phase === 1) {
        Text($r('app.string.toy_screw_hint')).fontSize(FontTokens.sizeCaption)
          .fontColor(this.vm.state.tray.length >= ExpansionScrews.capacity(this.vm.state) - 1 ?
            SemanticColors.warningText : SemanticColors.textSecondary)
      }
    }
  }

  @Builder
  ScrewPiece(rendered: ExpansionRenderPiece) {
    if (rendered.piece.kind === 0) {
      Stack() {
        Image(this.plate(rendered.piece.color)).objectFit(ImageFit.Fill)
          .width(Math.max(rendered.piece.w, rendered.piece.h) * this.unit())
          .height(Math.min(rendered.piece.w, rendered.piece.h) * this.unit())
          .rotate({ angle: rendered.piece.h > rendered.piece.w ? 90 : 0 })
      }.width(rendered.piece.w * this.unit()).height(rendered.piece.h * this.unit())
        .id('toy-plate-' + rendered.id)
        .translate({ x: rendered.piece.x * this.unit(), y: rendered.piece.y * this.unit() })
        .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 24 })))
    } else {
      Button({ type: ButtonType.Normal }) {
        if (this.vm.state.phase === 1) { ToyScrewHead({ color: rendered.piece.color }) }
        else {
          Image($r('app.media.toy_screw')).width('100%').height('100%').objectFit(ImageFit.Contain)
            .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
        }
      }.width(40 * this.unit()).height(40 * this.unit()).padding(0).backgroundColor(Color.Transparent)
        .translate({ x: (rendered.piece.x - 20) * this.unit(), y: (rendered.piece.y - 20) * this.unit() })
        .clickEffect(HarmonyMotion.press(this.getUIContext()))
        .enabled(this.screwFree(rendered.piece) && this.vm.state.outcome === 0)
        .accessibilityText(this.vm.state.phase === 1 ?
          $r('app.string.toy_colored_screw', rendered.piece.color, rendered.piece.owner + 1) :
          $r('app.string.expansion_screw', rendered.piece.owner + 1))
        .id('toy-screw-' + rendered.id)
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.rotate({ z: 1, angle: 100 }))
          .combine(TransitionEffect.scale({ x: 0.6, y: 0.6 })).animation({ duration: 180 }))
        .onClick(() => { this.tap(rendered.id); })
    }
  }

  @Builder
  CarPiece(rendered: ExpansionRenderPiece) {
    Button({ type: ButtonType.Normal }) {
      Stack() {
        Image(this.car(rendered.id)).objectFit(ImageFit.Fill)
          .width(rendered.piece.color % 2 === 0 ? this.carWidth(rendered.piece) : this.carHeight(rendered.piece))
          .height(rendered.piece.color % 2 === 0 ? this.carHeight(rendered.piece) : this.carWidth(rendered.piece))
          .rotate({ angle: rendered.piece.color * 90 }).hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
        Text(this.arrow(rendered.piece.color)).fontSize(FontTokens.sizeBody).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.toy_direction_ink')).hitTestBehavior(HitTestMode.None)
      }.width('100%').height('100%').renderGroup(true)
    }.width(this.carWidth(rendered.piece)).height(this.carHeight(rendered.piece))
      .padding(0).backgroundColor(Color.Transparent).clickEffect(HarmonyMotion.press(this.getUIContext()))
      .enabled(this.vm.state.outcome === 0)
      .translate({ x: rendered.piece.x * this.widthVp / this.vm.state.cols + 2,
        y: rendered.piece.y * this.widthVp / this.vm.state.rows + 2 })
      .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({
        x: rendered.piece.color === 1 ? 90 : rendered.piece.color === 3 ? -90 : 0,
        y: rendered.piece.color === 0 ? -90 : rendered.piece.color === 2 ? 90 : 0 })).animation({ duration: 180 }))
      .accessibilityText($r('app.string.expansion_car', rendered.id + 1, this.arrow(rendered.piece.color)))
      .id('toy-car-' + rendered.id).onClick(() => { this.tap(rendered.id); })
  }

  build() {
    Column({ space: SpacingTokens.sm }) {
      if (!this.parking) { this.ScrewTray() }
      Stack({ alignContent: Alignment.TopStart }) {
        Image(this.parking ? $r('app.media.toy_parking_board') : $r('app.media.toy_screw_board'))
          .width('100%').height('100%').objectFit(ImageFit.Fill)
          .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
        ForEach(this.vm.worldPieces, (rendered: ExpansionRenderPiece) => {
          if (this.parking) { this.CarPiece(rendered) } else { this.ScrewPiece(rendered) }
        }, (rendered: ExpansionRenderPiece) => rendered.id.toString())
      }.width(this.parking ? '100%' : Math.min(this.availableWidth, this.boardHeightLimit * 360 / 460))
        .aspectRatio(this.parking ? 1 : 360 / 460)
        .backgroundColor($r('app.color.toy_tray_background')).borderRadius($r('app.float.toy_board_radius')).clip(true)
        .id(this.parking ? 'toy-parking-board' : 'toy-screw-board')
        .onAreaChange((oldArea: Area, area: Area) => { this.widthVp = Number(area.width); })
    }.width('100%').onAreaChange((oldArea: Area, area: Area) => { this.availableWidth = Number(area.width); })
  }
}
