/**
 * 统一数字键盘组件 — 宇宙蓝 × 雪域灰
 * 按键使用 layoutWeight 自适应宽度，无固定像素
 */
import { DarkColors, FontTokens, RadiusTokens, ShadowTokens, SpacingTokens } from '../common/DesignTokens';

@ComponentV2
export struct NumberKeyboard {
  onDigit?: (digit: string) => void;
  onDelete?: () => void;
  onConfirm?: () => void;
  @Param confirmEnabled: boolean = true;
  @Param confirmLabel: string = '确定';

  build() {
    Column({ space: SpacingTokens.sm }) {
      ForEach(this.getRows(), (row: string[]) => {
        Row({ space: SpacingTokens.sm }) {
          ForEach(row, (key: string) => {
            Button() {
              if (key === '⌫') {
                SymbolGlyph($r('sys.symbol.delete_left'))
                  .fontSize(20)
                  .fontColor([this.getKeyTextColor(key)])
              } else {
                Text(key)
                  .fontFamily(FontTokens.family)
                  .fontSize(this.getKeyFontSize(key))
                  .fontWeight(key === '确定' ? FontTokens.weightMedium : FontTokens.weightRegular)
                  .fontColor(this.getKeyTextColor(key))
              }
            }
            .layoutWeight(1)
            .height(52)
            .backgroundColor(this.getKeyColor(key))
            .borderRadius(RadiusTokens.base)
            .shadow(this.getKeyShadow(key))
            .onClick(() => this.handleKey(key))
          })
        }
      })
    }
    .width('100%')
    .padding({ left: SpacingTokens.base, right: SpacingTokens.base })
  }

  getRows(): string[][] {
    return [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      [this.confirmEnabled ? '⌫' : '', '0', '确定']
    ];
  }

  getKeyFontSize(key: string): number {
    if (key === '确定') { return FontTokens.sizeBody; }
    if (key === '⌫') { return FontTokens.sizeBodyLarge; }
    return FontTokens.sizeHeadline;
  }

  getKeyColor(key: string): Resource {
    if (key === '确定') { return this.confirmEnabled ? DarkColors.primary : DarkColors.surfaceHover; }
    if (key === '⌫') { return DarkColors.error; }
    return DarkColors.surface;
  }

  getKeyTextColor(key: string): Resource {
    if (key === '确定') { return this.confirmEnabled ? DarkColors.textOnPrimary : DarkColors.textTertiary; }
    if (key === '⌫') { return DarkColors.textOnPrimary; }
    return DarkColors.textPrimary;
  }

  getKeyShadow(key: string): ShadowOptions | undefined {
    if (key === '确定' && this.confirmEnabled) {
      return ShadowTokens.button;
    }
    return undefined;
  }

  handleKey(key: string): void {
    if (key === '⌫') { this.onDelete?.(); }
    else if (key === '确定') { this.onConfirm?.(); }
    else { this.onDigit?.(key); }
  }
}
