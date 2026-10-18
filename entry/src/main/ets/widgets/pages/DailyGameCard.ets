export {};

const storage: LocalStorage = new LocalStorage();

interface CardLaunchParameters {
  widgetGameId: string;
  widgetResume: string;
}

@Entry(storage)
@Component
struct DailyGameCard {
  @LocalStorageProp('gameId') gameId: string = '';
  @LocalStorageProp('gameName') gameName: string = '';
  @LocalStorageProp('description') description: string = '';
  @LocalStorageProp('gameIcon') gameIcon: Resource | string = $r('app.media.game_2048');

  build() {
    Column({ space: $r('app.float.widget_gap') }) {
      Text($r('app.string.widget_daily_title'))
        .fontSize($r('app.float.widget_caption_size')).fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .width('100%').maxLines(1)
      Row({ space: $r('app.float.widget_gap') }) {
        Image(this.gameIcon).width($r('app.float.widget_daily_icon_size')).height($r('app.float.widget_daily_icon_size'))
          .objectFit(ImageFit.Contain)
        Text(this.gameName).fontSize($r('app.float.widget_title_size')).fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary')).layoutWeight(1).maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }.width('100%').layoutWeight(1)
      Text(this.description).fontSize($r('app.float.widget_caption_size'))
        .fontColor($r('sys.color.ohos_id_color_text_secondary')).width('100%').maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text($r('app.string.widget_play')).fontSize($r('app.float.widget_caption_size'))
        .fontWeight(FontWeight.Medium).fontColor($r('sys.color.ohos_id_color_emphasize')).width('100%')
    }.width('100%').height('100%').padding($r('app.float.widget_padding'))
      .backgroundColor($r('app.color.surface'))
      .onClick(() => {
        postCardAction(this, {
          action: 'router', abilityName: 'EntryAbility',
          params: { widgetGameId: this.gameId, widgetResume: 'false' } as CardLaunchParameters
        });
      })
  }
}
