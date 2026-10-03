/* Register only implemented games. The complete work order is documented separately. */
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
// ID, category, Chinese name, English name, Chinese rules, English rules.
const games = [
  ['blockfit', 'PUZZLE', '方块拼填', 'Block Fit', '选择下方拼块，再点击棋盘中的左上角放置位置。填满一行或一列即可消除。三个拼块用完后补充；达到目标分数获胜，无可放置拼块则结束。', 'Select a piece, then tap its top-left position on the board. Full rows and columns clear together. Use all three pieces to refill. Reach the target score to win; no legal placement ends the game.'],
  ['tilestack', 'PUZZLE', '堆叠三消', 'Tile Stack', '点击每叠最上面的牌收进七格卡槽，三个相同图案自动消除。清空所有牌获胜，卡槽装满则失败。角标显示该叠剩余张数。', 'Tap the top tile of a stack to put it in the seven-slot tray. Three identical tiles clear. Clear every stack to win; filling the tray loses. The badge shows the remaining stack depth.'],
  ['bubbleshooter', 'CLASSIC', '泡泡龙', 'Bubble Shooter', '点击游戏区域瞄准发射，泡泡碰壁反弹。连接至少三个同色泡泡即可消除，失去顶部连接的泡泡也会掉落。清空泡泡获胜，泡泡触及底线或炮弹用尽则失败。', 'Tap the arena to aim and fire. Shots bounce off side walls. Connect at least three bubbles of one color to clear them; detached bubbles fall too. Clear the board to win. Reaching the bottom line or running out of shots loses.'],
  ['fruitmerge', 'CLASSIC', '落果合成', 'Fruit Merge', '点击容器上方选择落点，投下一个水果。两个同等级水果碰到后合成更大的水果。合出最高等级获胜，水果持续越过警戒线则失败。', 'Tap the top of the container to drop a fruit. Touching fruits of the same tier merge into a larger one. Make the highest tier to win; fruit remaining above the warning line loses.'],
  ['watersort', 'PUZZLE', '倒水排序', 'Water Sort', '先点源瓶，再点目标瓶，将最上面一层倒入空瓶或同色顶层。每瓶最多四层。让每个有水的瓶子装满同一种颜色即可通关。可撤销上一步。', 'Tap a source tube, then a destination to pour one top layer into an empty tube or onto the same color. Each tube holds four layers. Fill each nonempty tube with a single color to win. Undo is available.'],
  ['arrowclear', 'PUZZLE', '箭头清除', 'Arrow Clear', '点击箭头沿朝向离开棋盘；前方有其他箭头会被阻挡。规划清除顺序，清空棋盘获胜。错误点击三次则失败。', 'Tap an arrow to send it out of the board. Another arrow in its path blocks it. Clear the board to win. Three blocked attempts lose.'],
  ['screwout', 'PUZZLE', '拆螺丝', 'Screw Out', '点击没有被上层板遮挡的螺丝，将其放入三个临时孔位。某块板的三颗螺丝全部卸下后，板和对应螺丝一同移走，腾出孔位。拆完所有板获胜。', 'Tap an uncovered screw to move it into one of three temporary holes. Removing all three screws of a plate clears that plate and its parked screws, freeing the holes. Remove every plate to win.'],
  ['parkingjam', 'PUZZLE', '停车场挪车', 'Parking Jam', '点击车辆，让它沿箭头方向驶出停车场。前方有车时不能驶出。规划车辆离场顺序，清空停车场即可获胜。', 'Tap a car to drive it out in its arrow direction. Cars ahead block the exit. Plan the exit order and clear the parking lot to win.'],
  ['runner', 'REACTION', '无尽跑酷', 'Endless Runner', '使用左右按钮切换三条跑道，躲开路障并收集金币。速度逐渐提升，达到目标分数获胜，碰到路障结束。', 'Switch between three lanes with the left and right buttons. Avoid roadblocks and collect coins as speed increases. Reach the target score to win; hitting a roadblock ends the run.'],
  ['blackhole', 'CLASSIC', '黑洞吞噬', 'Growing Hole', '点击或拖动地面引导黑洞，吞下比自己小的物体并逐渐长大。倒计时内吞下所有物体即可获胜，大物体需要先吃小物体才能吞下。', 'Tap or drag to guide a growing hole. Swallow smaller objects to grow enough for larger ones. Clear every object before time runs out to win.'],
  ['fisheat', 'CLASSIC', '大鱼吃小鱼', 'Fish Feast', '点击或拖动水面引导小鱼，吃掉更小的鱼获得成长。碰到明显比自己大的鱼会失败，吃够目标数量即可通关。', 'Tap or drag to guide your fish. Eat smaller fish to grow. A substantially larger fish ends the game. Eat the target number to win.'],
  ['sokoban', 'PUZZLE', '推箱子', 'Sokoban', '使用方向按钮移动，将所有箱子推到圆点目标上。每次只能推一个箱子，不能拉箱子。卡住时可撤销或重新开始。', 'Move with the direction buttons and push every box onto a marked goal. Push one box at a time; boxes cannot be pulled. Undo or restart if stuck.'],
  ['pipes', 'PUZZLE', '管道连通', 'Pipe Connect', '点击管道顺时针旋转，从蓝色起点连到终点。所有管道都必须接通，不能留下漏水的断口。蓝色表示当前通水区域。', 'Tap a pipe to rotate it clockwise. Connect the blue source to the outlet through every pipe with no open leaks. Blue marks the connected flow.'],
  ['differences', 'PUZZLE', '找不同', 'Spot the Difference', '对比左右两幅图，在右图点击不同的物品。找出全部差异获胜，点错三次则结束。已找到的物品会标出边框。', 'Compare the two scenes and tap changed objects in the right scene. Find every difference to win. Three incorrect taps end the game. Found differences receive a border.'],
  ['roomdefense', 'CLASSIC', '房间塔防', 'Room Defense', '在六个孔位建造炮塔，消灭进攻房间的敌人。房间每秒产生金币，可升级炮塔或修复房门。守住房间并消灭全部敌人即可通关。', 'Build towers in six slots to defend the room. Earn coins every second, upgrade towers and repair the door. Defeat every enemy while keeping the room intact to win.'],
  ['basketball', 'REACTION', '篮球投篮', 'Basketball Shots', '点击篮筐附近的预期落点，篮球将沿抛物线投出。篮球下落穿过篮筐才算命中，普通及困难模式篮筐会移动。十六次投篮中达到目标进球数即可获胜。', 'Tap near the hoop to aim a high arc. The ball must pass down through the hoop to score. The hoop moves on normal and hard modes. Make the target number of baskets within sixteen shots.'],
  ['solitaire', 'BOARD', '经典纸牌', 'Klondike Solitaire', '翻开牌库抽一张牌。点击选中明牌，再点击目标列移动；列间必须按红黑交替、点数递减叠放，空列只收 K。选中顶牌后点击归位，从 A 开始按花色递增放入四个基础堆，收齐全部牌获胜。', 'Draw one card from the stock. Select a face-up card and tap a destination column. Build columns in alternating colors and descending ranks; only kings fill empty columns. Use Foundation to build each suit from ace to king. Collect all cards to win.'],
  ['characters', 'PUZZLE', '汉字拆组', 'Character Builder', '观察目标汉字，点击对应部件进行组合；同一部件可以重复选择。点击检查验证组合，八题全部完成获胜，三次错误则结束。', 'Study the target Chinese character and choose its components. A component can be chosen more than once. Check the combination to advance. Complete eight characters to win; three mistakes end the game.'],
  ['rhythm', 'REACTION', '节奏落键', 'Falling Beats', '点击开始后，音符沿四条轨道落下。当音符到达横线时点击对应琴键，越接近横线得分越高。完成整段节奏获胜，漏按或误按累计五次结束。', 'Start the sequence and tap the matching lane key as a note reaches the line. Closer timing earns more points. Complete the sequence to win; five missed or incorrect taps end the game.'],
  ['restaurant', 'CLASSIC', '迷你餐厅', 'Mini Restaurant', '点击菜品花费两枚金币开始制作，等待完成后会进入备餐区。点击顾客，将对应菜品送出并赚取十枚金币。两分钟内完成目标订单即可通关，流失五位顾客则失败。', 'Spend two coins to cook a dish and wait for it to enter the serving stock. Tap a customer to serve the requested dish and earn ten coins. Complete the target orders within two minutes. Losing five customers ends the game.']
];
games.push(
  ['linktiles', 'PUZZLE', '连连看', 'Tile Connect', '依次点击两张相同图案的牌，连线最多转两次弯，且不能穿过其他牌。连线可以绕过棋盘边缘。清空全部牌获胜；没有可消除配对时，可重排并显示一组提示。', 'Tap two matching tiles. Their connecting path may turn at most twice and must avoid other tiles. Paths can go around the board border. Clear every tile to win. Rearrange provides a playable pair and a hint.'],
  ['mahjongsolitaire', 'PUZZLE', '麻将接龙', 'Mahjong Solitaire', '配对消除两张相同图案的自由牌：上方没有其他牌覆盖，且左右至少一侧没有相邻牌。清空所有层获胜。灰色牌暂时不可取，可重排剩余牌或撤销。', 'Pair two matching free tiles: no tile covers either one, and at least one horizontal side is open. Clear all layers to win. Dimmed tiles are blocked. Rearrange the remaining tiles or undo if stuck.'],
  ['groupclear', 'PUZZLE', '点击群消', 'Cluster Clear', '点击至少两个上下左右相连的同色方块，整组消除并获得组数平方倍的分数。方块向下掉落，空列向左收拢。清空棋盘或在无可消除组时达到目标分数获胜。', 'Tap a group of at least two orthogonally adjacent blocks of one color. Larger groups earn squared bonuses. Blocks fall down and empty columns slide left. Clear the board or meet the target when no groups remain to win.'],
  ['slotpair', 'PUZZLE', '落槽配对消除', 'Drop Pairs', '点击一列投下下一块方块，至少两个相邻同色方块自动消除并触发连锁。规划落点，让全部方块投完后棋盘为空即可获胜；所有列装满或投完仍有残留则失败。', 'Tap a column to drop the next block. Adjacent groups of at least two matching blocks clear and cascade. Finish the sequence with an empty board to win. A full board or leftover blocks at the end loses.'],
  ['buscolor', 'PUZZLE', '乘客上车', 'Passenger Boarding', '乘客按队列顺序上同色巴士，每辆车坐满三人自动离场。点击三条车道最前面的巴士，送入三个候车位。让全部乘客上车获胜，候车位堵住时可撤销调整发车顺序。', 'Passengers board matching buses in queue order. A bus leaves when its three seats fill. Tap the front bus of a lane to send it to one of three waiting slots. Board everyone to win. Undo to change the dispatch order if slots are blocked.'],
  ['yarn', 'PUZZLE', '毛线收卷', 'Yarn Reels', '先选一个卷轴，再点击毛线柱，收走顶端连续的同色线段。空卷轴可以接任何颜色，已有毛线的卷轴只能接同色。每卷八段自动收起，收完所有毛线获胜。', 'Choose a reel, then tap a yarn column to wind its exposed run of one color. Empty reels accept any color; partially filled reels accept only their color. Eight units complete a reel. Wind all yarn to win.'],
  ['sand', 'PUZZLE', '沙画吸色', 'Sand Vacuum', '选择下方颜色吸管，再点击同色沙粒，吸走上下左右连通的沙粒。每次最多装满一个八粒收集罐，剩余沙粒向下落。每种颜色收满两罐，清空沙画即可通关。', 'Select a colored nozzle and tap matching sand. Collect connected grains, up to the remaining space in an eight-grain can. Sand falls down afterward. Fill two cans per color and clear the picture to win.'],
  ['untangle', 'PUZZLE', '绳结解开', 'Untangle', '按住圆点拖动，调整绳索端点的位置，让不共用端点的绳索不再交叉或重叠。橙色绳索表示仍有交叉。交叉数降为零获胜，可撤销整次拖动。', 'Drag the numbered nodes until ropes with separate endpoints no longer cross, touch or overlap. Orange ropes still have intersections. Reduce the intersection count to zero to win. Undo reverses a complete drag.']
);
const completion = require('./expansion-completion-catalog.cjs');
games.push(...completion.games);
const write = (relative, contents) => { const file = path.join(root, relative); fs.mkdirSync(path.dirname(file), {recursive:true}); fs.writeFileSync(file, contents, 'utf8'); };
const prefix = 'entry/src/main/';
write(prefix + 'ets/model/ExpansionCatalog.ets', `import { GameCategory, GameInfo } from '../common/GameConstants';\n\n// Generated by scripts/generate-expansion-catalog.cjs; implemented entries only.\nexport const EXPANSION_IDS: string[] = [${games.map(g=>`'${g[0]}'`).join(', ')}];\n\nexport function expansionGames(): GameInfo[] {\n  return [\n${games.map(g=>`    { id: '${g[0]}', name: $r('app.string.game_${g[0]}_name'), category: GameCategory.${g[1]},\n      icon: $r('app.media.game_${g[0]}'), description: $r('app.string.game_${g[0]}_desc'),\n      highScore: 0, playCount: 0, scoreLabel: $r('app.string.collection_score') }`).join(',\n')}\n  ];\n}\n\nexport function expansionRules(id: string): Resource {\n${games.map(g=>`  if (id === '${g[0]}') { return $r('app.string.game_${g[0]}_rules'); }`).join('\n')}\n  return $r('app.string.collection_empty');\n}\n`);
const shared = [
  ['art_try_again', '再试一次', 'Try again'],
  ['art_ludo_token', '玩家 %d，飞机 %d', 'Player %d, plane %d'],
  ['expansion_rearrange', '重排并提示', 'Rearrange and hint'],
  ['expansion_next_tile', '下一块', 'Next block'],
  ['expansion_drop_column', '投到第 %d 列', 'Drop in column %d'],
  ['expansion_mahjong_tile', '牌 %d，图案 %s，第 %d 层', 'Tile %d, symbol %s, layer %d'],
  ['expansion_passenger_queue', '乘客队列 · 从左到右上车', 'Passenger queue · board from left to right'],
  ['expansion_parking_slots', '候车位 %d / 3', 'Waiting slots %d / 3'],
  ['expansion_launch_bus', '第 %d 车道第 %d 辆巴士', 'Lane %d, bus %d'],
  ['expansion_bus_stuck', '候车位已满，撤销后调整发车顺序', 'Waiting slots are full. Undo and change the dispatch order.'],
  ['expansion_unwind_column', '收卷第 %d 柱毛线', 'Wind yarn from column %d'],
  ['expansion_choose_reel', '选择一个卷轴，再点击毛线柱', 'Choose a reel, then tap a yarn column'],
  ['expansion_reel', '卷轴 %d', 'Reel %d'],
  ['expansion_capacity', '%d / %d', '%d / %d'],
  ['expansion_choose_pump', '选择颜色吸管，再点击同色沙粒', 'Choose a nozzle, then tap matching sand'],
  ['expansion_crossings', '剩余交叉 %d', 'Intersections left %d'],
  ['expansion_node', '拖动节点 %d', 'Drag node %d'],
  ['module_desc', `玩趣盒 - 六大分类，${33 + games.length} 款离线小游戏`, `LittleGames - ${33 + games.length} offline games across six categories`],
  ['app_splash_subtitle', `${33 + games.length} 款小游戏，随手开一局。`, `${33 + games.length} mini-games. Pick one and play.`],
  ['settings_about_tagline', `六大分类，${33 + games.length} 款小游戏`, `${33 + games.length} little games across six categories`],
  ['expansion_target', '目标分数 %d', 'Target score %d'],
  ['expansion_remaining', '剩余 %d · 步数 %d', 'Remaining %d · Moves %d'],
  ['expansion_errors', '失误 %d / 3', 'Mistakes %d / 3'],
  ['expansion_shots', '剩余炮弹 %d', 'Shots left %d'],
  ['expansion_tray', '卡槽 %d / 7', 'Tray %d / 7'],
  ['expansion_undo', '撤销上一步', 'Undo last move'],
  ['expansion_ready', '点击开始', 'Tap to start'],
  ['expansion_resume', '继续游戏', 'Resume'],
  ['expansion_paused', '游戏已暂停', 'Paused'],
  ['expansion_restart', '重新开始', 'Restart'],
  ['expansion_drop', '下一颗水果：%d', 'Next fruit: %d'],
  ['expansion_next_ball', '下一颗泡泡', 'Next bubble'],
  ['expansion_warning', '警戒线', 'Warning line'],
  ['expansion_piece', '拼块 %d', 'Piece %d'],
  ['expansion_stack', '牌叠 %d，图案 %d，剩余 %d 张', 'Stack %d, symbol %d, depth %d'],
  ['expansion_tube', '瓶 %d，从下到上：%s', 'Tube %d, bottom to top: %s'],
  ['expansion_screw', '第 %d 块板的螺丝', 'Screw of plate %d'],
  ['expansion_car', '车辆 %d，方向 %s', 'Car %d, direction %s'],
  ['expansion_empty', '空', 'Empty'],
  ['expansion_selected', '已选中', 'Selected'],
  ['expansion_cell', '第 %d 行第 %d 列：%s', 'Row %d, column %d: %s'],
  ['expansion_blocked', '这里被阻挡，请换一个位置', 'Blocked. Try another position.'],
  ['expansion_full', '孔位已满，可撤销后调整拆解顺序', 'All temporary holes are full. Undo to change the removal order.'],
  ['expansion_finished', '本局结束', 'Game over'],
  ['expansion_controls_hint', '选择拼块，再点击棋盘放置', 'Select a piece, then tap the board'],
  ['expansion_left', '向左', 'Left'], ['expansion_right', '向右', 'Right'],
  ['expansion_move', '移动：%s', 'Move: %s'],
  ['expansion_time', '剩余时间 %d 秒', 'Time left: %d s'],
  ['expansion_progress', '进度 %d / %d', 'Progress %d / %d'],
  ['expansion_reference', '参考图', 'Reference'], ['expansion_changed', '找出差异', 'Find differences'],
  ['expansion_coins', '金币 %d · 房门 %d', 'Coins %d · Door %d'],
  ['expansion_tower', '炮塔 %d：建造或升级', 'Tower %d: build or upgrade'],
  ['expansion_repair', '修复房门（25 金币）', 'Repair door (25 coins)'],
  ['expansion_stock', '牌库 %d', 'Stock %d'], ['expansion_foundation', '归位', 'Foundation'],
  ['expansion_clear', '清空选择', 'Clear selection'], ['expansion_check', '检查组合', 'Check combination'],
  ['expansion_character', '目标汉字：%s', 'Target character: %s'],
  ['expansion_key', '轨道 %d', 'Lane %d'],
  ['expansion_food_0', '饭团', 'Rice ball'], ['expansion_food_1', '汤面', 'Noodles'], ['expansion_food_2', '烤串', 'Skewers'],
  ['expansion_food_stock', '备餐 %d', 'Ready %d'], ['expansion_customer', '顾客 %d · 剩余 %d 秒', 'Customer %d · %d s left'],
  ['expansion_money', '金币 %d', 'Coins %d'], ['expansion_cooking', '制作中', 'Cooking'],
  ['expansion_color_1', '蓝色', 'Blue'], ['expansion_color_2', '珊瑚色', 'Coral'],
  ['expansion_color_3', '金色', 'Gold'], ['expansion_color_4', '绿色', 'Green'],
  ['expansion_color_5', '紫色', 'Violet'], ['expansion_color_6', '青色', 'Cyan'], ...completion.strings
];
for (const locale of ['base','zh_CN','en_US']) {
  const file = prefix + `resources/${locale}/element/string.json`;
  const doc = JSON.parse(fs.readFileSync(path.join(root,file),'utf8')); const en = locale==='en_US';
  const values = games.flatMap(g=>[
    {name:`game_${g[0]}_name`,value:g[en?3:2]},
    {name:`game_${g[0]}_desc`,value:g[en?5:4].split(en ? '. ' : '。')[0]},
    {name:`game_${g[0]}_rules`,value:g[en?5:4]}
  ]).concat(shared.map(s=>({name:s[0],value:s[en?2:1]})));
  const keys = new Set(values.map(v=>v.name));if(keys.size!==values.length)throw new Error('Duplicate generated string resource');doc.string=doc.string.filter(v=>!keys.has(v.name)).concat(values);write(file,JSON.stringify(doc,null,2)+'\n');
}
const palette = [['#397AD4','#88B7FF'],['#D35D70','#FF9CAD'],['#BB852C','#FFD078'],['#2E9879','#7BDFC0'],['#9564C4','#CBA5F5'],['#268EAA','#7AD4EA']];
for (const theme of ['base','dark']) {
  const file=prefix+`resources/${theme}/element/color.json`;const doc=JSON.parse(fs.readFileSync(path.join(root,file),'utf8'));
  const colors=palette.map((p,i)=>({name:'expansion_color_'+(i+1),value:p[theme==='dark'?1:0]}));
  const keys=new Set(colors.map(c=>c.name));doc.color=doc.color.filter(c=>!keys.has(c.name)).concat(colors);write(file,JSON.stringify(doc,null,2)+'\n');
  for (const g of games) {
    const ink=theme==='dark'?'#9DC9FF':'#326AB5';const bg=theme==='dark'?'#1D304B':'#E6F0FF';let shapes='';
    if(g[0]==='blockfit')shapes='<path d="M22 24h24v24H22zM48 24h24v24H48zM48 50h24v24H48z"/>';
    else if(g[0]==='tilestack')shapes='<rect x="25" y="20" width="42" height="52" rx="7" opacity=".35"/><rect x="21" y="28" width="42" height="52" rx="7"/><circle cx="42" cy="52" r="9" fill="'+bg+'"/>';
    else if(g[0]==='bubbleshooter')shapes='<circle cx="32" cy="30" r="13"/><circle cx="61" cy="30" r="13"/><circle cx="46" cy="54" r="13"/><path d="M46 76l7 9H39z"/>';
    else if(g[0]==='fruitmerge')shapes='<circle cx="47" cy="55" r="26"/><path d="M47 29q-3-16 17-14q1 15-17 14z"/>';
    else if(g[0]==='watersort')shapes='<path d="M20 20h22v51a11 11 0 01-22 0zM54 20h22v51a11 11 0 01-22 0z" fill="none" stroke="'+ink+'" stroke-width="5"/><path d="M23 43h16v27a8 8 0 01-16 0zM57 55h16v15a8 8 0 01-16 0z"/>';
    else if(g[0]==='arrowclear')shapes='<path d="M20 28h50l-12-12m12 12L58 40M76 65H26l12-12M26 65l12 12" fill="none" stroke="'+ink+'" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>';
    else if(g[0]==='screwout')shapes='<rect x="18" y="29" width="60" height="36" rx="8" opacity=".4"/><circle cx="32" cy="47" r="11"/><circle cx="64" cy="47" r="11"/><path d="M25 47h14M57 47h14" stroke="'+bg+'" stroke-width="4"/>';
    else if(g[0]==='parkingjam')shapes='<rect x="17" y="24" width="26" height="51" rx="8"/><rect x="51" y="30" width="27" height="43" rx="8" opacity=".5"/><path d="M23 36h14M57 42h15" stroke="'+bg+'" stroke-width="6"/>';
    else if(g[0]==='runner')shapes='<circle cx="53" cy="23" r="8"/><path d="M38 42l11-11 14 17 13-4M48 37l-5 19-16 18M43 56l17 6 5 16" fill="none" stroke="'+ink+'" stroke-width="7" stroke-linecap="round"/>';
    else if(g[0]==='blackhole')shapes='<ellipse cx="48" cy="59" rx="30" ry="15"/><circle cx="31" cy="28" r="9" opacity=".5"/><path d="M54 19h18v20H54z" opacity=".6"/>';
    else if(g[0]==='fisheat')shapes='<ellipse cx="46" cy="49" rx="23" ry="17"/><path d="M64 48l15-17v34z"/><circle cx="36" cy="45" r="4" fill="'+bg+'"/>';
    else if(g[0]==='sokoban')shapes='<rect x="23" y="24" width="48" height="48" rx="6"/><path d="M28 30l37 36m0-36L28 66" stroke="'+bg+'" stroke-width="5"/>';
    else if(g[0]==='pipes')shapes='<path d="M23 75V48h25V24h28" fill="none" stroke="'+ink+'" stroke-width="15" stroke-linejoin="round"/>';
    else if(g[0]==='differences')shapes='<circle cx="32" cy="42" r="17" fill="none" stroke="'+ink+'" stroke-width="6"/><path d="M44 56l14 19M61 29h15v22H61z"/><circle cx="64" cy="67" r="7" opacity=".5"/>';
    else if(g[0]==='roomdefense')shapes='<path d="M19 43l29-23 29 23v33H19z" opacity=".45"/><rect x="37" y="43" width="22" height="33" rx="5"/><path d="M48 36v-9" stroke="'+ink+'" stroke-width="8"/>';
    else if(g[0]==='basketball')shapes='<circle cx="47" cy="48" r="28" fill="none" stroke="'+ink+'" stroke-width="6"/><path d="M19 48h56M47 20v56M30 25q22 23 0 47M64 25q-22 23 0 47" fill="none" stroke="'+ink+'" stroke-width="4"/>';
    else if(g[0]==='solitaire')shapes='<rect x="24" y="18" width="44" height="62" rx="7"/><path d="M46 35l13 13-13 13-13-13z" fill="'+bg+'"/>';
    else if(g[0]==='characters')shapes='<path d="M20 26h25v42H20zM56 24h20v45H56zM20 46h25M56 43h20M66 24v45" fill="none" stroke="'+ink+'" stroke-width="5"/>';
    else if(g[0]==='rhythm')shapes='<path d="M21 20h10v56H21zM44 20h10v56H44zM67 20h10v56H67z" opacity=".3"/><path d="M21 50h10v20H21zM44 25h10v20H44zM67 40h10v20H67z"/>';
    else if(g[0]==='linktiles')shapes='<rect x="17" y="28" width="24" height="32" rx="5"/><rect x="55" y="28" width="24" height="32" rx="5"/><path d="M29 63v12h38V63" fill="none" stroke="'+ink+'" stroke-width="4"/>';
    else if(g[0]==='mahjongsolitaire')shapes='<rect x="19" y="29" width="34" height="46" rx="6" opacity=".4"/><rect x="43" y="20" width="34" height="46" rx="6"/><path d="M53 43h14m-7-7v14" stroke="'+bg+'" stroke-width="4"/>';
    else if(g[0]==='groupclear')shapes='<path d="M20 23h24v24H20zM48 23h24v24H48zM20 51h24v24H20z"/><circle cx="61" cy="63" r="9" opacity=".4"/>';
    else if(g[0]==='slotpair')shapes='<path d="M21 41v33h54V41M48 17v23m-8-8 8 8 8-8" fill="none" stroke="'+ink+'" stroke-width="5"/><rect x="28" y="50" width="18" height="18" rx="3"/><rect x="50" y="50" width="18" height="18" rx="3"/>';
    else if(g[0]==='buscolor')shapes='<rect x="19" y="26" width="58" height="45" rx="9"/><rect x="26" y="33" width="44" height="18" rx="3" fill="'+bg+'"/><circle cx="29" cy="73" r="7"/><circle cx="67" cy="73" r="7"/>';
    else if(g[0]==='yarn')shapes='<ellipse cx="48" cy="25" rx="24" ry="8"/><path d="M25 26v40q23 14 46 0V26z" opacity=".5"/><path d="M25 41q23 14 46 0M25 52q23 14 46 0M25 63q23 14 46 0" fill="none" stroke="'+ink+'" stroke-width="5"/>';
    else if(g[0]==='sand')shapes='<path d="M54 19h21v34L63 64 54 53z"/><path d="M20 54h27v22H20z" opacity=".4"/><circle cx="28" cy="40" r="4"/><circle cx="41" cy="42" r="4"/><circle cx="21" cy="29" r="4"/>';
    else if(g[0]==='untangle')shapes='<path d="M24 25l48 47M72 25L24 72M24 25h48v47H24z" fill="none" stroke="'+ink+'" stroke-width="4"/><circle cx="24" cy="25" r="8"/><circle cx="72" cy="25" r="8"/><circle cx="24" cy="72" r="8"/><circle cx="72" cy="72" r="8"/>';
    else if (g[0] === 'restaurant') shapes='<path d="M20 59q28 30 56 0z"/><path d="M34 48q-10-9 0-19M49 48q-10-9 0-19M64 48q-10-9 0-19" fill="none" stroke="'+ink+'" stroke-width="5" stroke-linecap="round"/>';
    else { shapes=completion.icon(g[0],ink,bg); }
    write(prefix+`resources/${theme}/media/game_${g[0]}.svg`,`<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96"><rect x="4" y="4" width="88" height="88" rx="24" fill="${bg}"/><g fill="${ink}">${shapes}</g></svg>\n`);
  }
}
const floats={expansion_arena_width:'360vp',expansion_arena_height:'460vp',expansion_control_height:'52vp',expansion_board_max:'520vp',expansion_tube_height:'172vp'};
const floatFile=prefix+'resources/base/element/float.json';const floatDoc=JSON.parse(fs.readFileSync(path.join(root,floatFile),'utf8'));
floatDoc.float=floatDoc.float.filter(v=>!Object.hasOwn(floats,v.name)).concat(Object.entries(floats).map(([name,value])=>({name,value})));write(floatFile,JSON.stringify(floatDoc,null,2)+'\n');
console.log(`Generated ${games.length} implemented game entries and bilingual/light-dark resources.`);
write(prefix+'resources/base/media/expansion_puzzle_scene.svg', '<svg xmlns="http://www.w3.org/2000/svg" width="500" height="500" viewBox="0 0 500 500"><rect width="500" height="500" fill="#C9E8F4"/><circle cx="405" cy="75" r="38" fill="#FFD37A"/><path d="M0 260L145 95l135 165L385 165l115 95v240H0z" fill="#83BCA1"/><path d="M0 340q140-160 300-55t200-30v245H0z" fill="#4F987F"/><path d="M250 280q-80 90 25 120t-5 100H145q140-80 35-110t70-110z" fill="#72BFD6"/><path d="M30 290h125v110H30z" fill="#F3D3A5"/><path d="M10 290l85-75 85 75z" fill="#C27061"/><path d="M72 335h36v65H72z" fill="#795D61"/><path d="M42 310h26v26H42zM120 310h26v26h-26z" fill="#C9E8F4"/><rect x="368" y="320" width="20" height="120" fill="#8A6D59"/><circle cx="378" cy="310" r="60" fill="#2F7969"/><circle cx="422" cy="336" r="44" fill="#3B8A6B"/><path d="M305 447h170M310 475h160" stroke="#A9CC8B" stroke-width="8"/><g fill="#F5D2BE"><circle cx="45" cy="454" r="9"/><circle cx="110" cy="480" r="11"/><circle cx="315" cy="425" r="8"/></g><path d="M210 65h60m-42-10q12-20 24 0" fill="none" stroke="#FFFFFF" stroke-width="14" stroke-linecap="round"/></svg>\n');
for (let tone=0;tone<4;tone++) {
  const rate=22050, samples=Math.round(rate*0.28), wav=Buffer.alloc(44+samples*2); wav.write('RIFF',0); wav.writeUInt32LE(wav.length-8,4); wav.write('WAVEfmt ',8); wav.writeUInt32LE(16,16); wav.writeUInt16LE(1,20); wav.writeUInt16LE(1,22); wav.writeUInt32LE(rate,24); wav.writeUInt32LE(rate*2,28); wav.writeUInt16LE(2,32); wav.writeUInt16LE(16,34); wav.write('data',36); wav.writeUInt32LE(samples*2,40);
  const frequency=[261.63,293.66,329.63,392][tone];
  for(let i=0;i<samples;i++) wav.writeInt16LE(Math.round(Math.sin(i/rate*frequency*Math.PI*2)*13000*Math.min(1,i/180)*Math.max(0,1-i/samples)),44+i*2);
  write(prefix+`resources/rawfile/expansion_tone_${tone}.wav`,wav);
}
require('./generate-expansion-art.cjs').generate();
module.exports = { games };
