export {};

const storage: LocalStorage = new LocalStorage();

interface CardLaunchParameters {
  widgetGameId: string;
  widgetResume: string;
}

@Entry(storage)
@Component
struct ContinueGameCard {
  @LocalStorageProp('saved2048') saved2048: boolean = false;
  @LocalStorageProp('savedSudoku') savedSudoku: boolean = false;

  hasSave(gameId: string): boolean {
    return gameId === '2048' ? this.saved2048 : this.savedSudoku;
  }

  openGame(gameId: string, resume: boolean): void {
    postCardAction(this, {
      action: 'router', abilityName: 'EntryAbility',
      params: { widgetGameId: gameId, widgetResume: resume ? 'true' : 'false' } as CardLaunchParameters
    });
  }

  @Builder
  GameTile(gameId: string, name: Resource, icon: Resource) {
    Column({ space: $r('app.float.widget_gap') }) {
      Row({ space: $r('app.float.widget_gap') }) {
        Image(icon).width($r('app.float.widget_icon_size')).height($r('app.float.widget_icon_size'))
          .objectFit(ImageFit.Contain)
        Text(name).fontSize($r('app.float.widget_title_size')).fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary')).layoutWeight(1).maxLines(1)
      }.width('100%')
      Text(this.hasSave(gameId) ? $r('app.string.widget_saved_game') : $r('app.string.widget_no_save'))
        .fontSize($r('app.float.widget_caption_size')).fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .maxLines(1).width('100%')
      Text(this.hasSave(gameId) ? $r('app.string.widget_continue') : $r('app.string.widget_start'))
        .fontSize($r('app.float.widget_caption_size')).fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_emphasize')).width('100%')
    }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      .onClick(() => { this.openGame(gameId, this.hasSave(gameId)); })
  }

  build() {
    Column({ space: $r('app.float.widget_gap') }) {
      Text($r('app.string.widget_continue_title')).width('100%')
        .fontSize($r('app.float.widget_caption_size')).fontColor($r('sys.color.ohos_id_color_text_secondary'))
      Row({ space: $r('app.float.widget_tile_gap') }) {
        this.GameTile('2048', $r('app.string.game_2048_name'), $r('app.media.game_2048'))
        this.GameTile('sudoku', $r('app.string.game_sudoku_name'), $r('app.media.game_sudoku'))
      }.width('100%').layoutWeight(1)
    }.width('100%').height('100%').padding($r('app.float.widget_padding')).backgroundColor($r('app.color.surface'))
  }
}
