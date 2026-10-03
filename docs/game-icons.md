# LittleGames 游戏图标

2026-10-03：新老 100 款游戏统一为柔和立体的透明 SVG 小模型，全部提供浅色、深色版本。造型、颜色、留白和投影共用一套规范；玩法保留独立轮廓。首页、分类页及“我的”页共用主题图标底色。

[统一图标交付记录](art/unified-icons.md) · [浅色全览](art/game-icons-light.png) · [深色全览](art/game-icons-dark.png) · [手机验证](device-acceptance/unified-icons-2026-10-03/README.md)

图标资源为 entry/src/main/resources/{base,dark}/media/game_*.svg，各目录 100 个，画布均为 120×120。保留原来的资源名称，目录、最近游戏和排行榜自动引用统一版本。

唯一图标生成入口为 node scripts/generate-game-icons.cjs。Collection 和 Expansion 的美术生成器均在末尾调用此入口，重建目录或对局美术不会恢复旧图标。无需外部图片、字体或网络。

原 13 款 PNG、最初生成说明及提示词已保留在[历史图标归档](art/legacy-icons/README.md)，不再进入应用资源包。13 款游戏的对局素材说明仍见[对局美术](gameplay-art.md)。
