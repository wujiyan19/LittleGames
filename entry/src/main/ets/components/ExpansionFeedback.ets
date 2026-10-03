import { ExpansionViewModel } from '../viewmodel/ExpansionViewModel';
import { SemanticColors, FontTokens, RadiusTokens, SpacingTokens } from '../common/DesignTokens';
import { range } from '../common/Range';

/** One bounded feedback burst; never owns a game loop or changes layout during animation. */
@ComponentV2
export struct ExpansionFeedback {
  @Param vm: ExpansionViewModel = new ExpansionViewModel();
  @Local progress: number = 1;
  @Local kind: number = 0;
  @Local gain: number = 0;
  private startTimer: number = -1;
  private generation: number = 0;
  private mounted: boolean = false;

  aboutToAppear(): void { this.mounted = true; }
  aboutToDisappear(): void { this.mounted = false; this.cancel(); }
  cancel(): void {
    this.generation++;
    if (this.startTimer >= 0) { clearTimeout(this.startTimer); this.startTimer = -1; }
    this.getUIContext().animateTo({ duration: 0 }, () => { this.progress = 1; });
  }
  @Monitor('vm.effectsEnabled')
  visibilityChanged(): void { if (!this.vm.effectsEnabled) { this.cancel(); } }
  @Monitor('vm.feedbackSerial')
  play(): void {
    if (!this.mounted) { return; }
    this.cancel();
    if (!this.vm.effectsEnabled || this.vm.state.outcome !== 0 || this.vm.feedbackKind === 0) { return; }
    this.kind = this.vm.feedbackKind; this.gain = this.vm.feedbackGain;
    this.getUIContext().animateTo({ duration: 0 }, () => { this.progress = 0; });
    const current: number = this.generation;
    this.startTimer = setTimeout(() => {
      this.startTimer = -1;
      if (!this.mounted || !this.vm.effectsEnabled || current !== this.generation) { return; }
      this.getUIContext().animateTo({ duration: this.kind === 2 ? 360 : 620, curve: Curve.EaseOut }, () => { this.progress = 1; });
    }, 16);
  }
  build() {
    Stack() {
      Image($r('app.media.exp_ripple')).width($r('app.float.art_feedback_ring')).height($r('app.float.art_feedback_ring')).objectFit(ImageFit.Contain)
        .scale({ x: 0.7 + this.progress * 1.5, y: 0.7 + this.progress * 1.5 }).opacity((1 - this.progress) * 0.65);
      if (this.kind === 1) {
        ForEach(range(6), (index: number) => {
          Image($r('app.media.exp_spark')).width($r('app.float.art_feedback_particle')).height($r('app.float.art_feedback_particle')).objectFit(ImageFit.Contain)
            .translate({ x: Math.cos(index * Math.PI / 3) * this.progress * 80, y: Math.sin(index * Math.PI / 3) * this.progress * 60 })
            .rotate({ angle: index * 60 + this.progress * 90 }).opacity(1 - this.progress);
        }, (index: number) => index.toString());
      }
      Text(this.kind === 1 ? '+' + this.gain.toString() : this.kind === 2 ? $r('app.string.art_try_again') : '')
        .fontSize(FontTokens.sizeSubtitle).fontWeight(FontWeight.Bold)
        .fontColor(this.kind === 2 ? SemanticColors.error : SemanticColors.success)
        .padding(SpacingTokens.sm).backgroundColor(SemanticColors.surface).borderRadius(RadiusTokens.full)
        .translate({ y: -this.progress * 32 }).opacity(1 - this.progress)
        .scale({ x: 0.9 + this.progress * 0.15, y: 0.9 + this.progress * 0.15 });
    }.width($r('app.float.art_feedback_width')).height($r('app.float.art_feedback_height')).renderGroup(true).hitTestBehavior(HitTestMode.None).accessibilityLevel('no');
  }
}
