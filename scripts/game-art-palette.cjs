// Shared materials for game icons and the original gameplay artwork.
const gradient = (id, top, bottom) => `<linearGradient id="${id}" x1="0" y1="0" x2=".25" y2="1"><stop stop-color="${top}"/><stop offset="1" stop-color="${bottom}"/></linearGradient>`;
function palette(theme) {
  const dark = theme === 'dark';
  return { ink: dark ? '#DAE8FF' : '#304A69', edge: dark ? '#516884' : '#9CB7D0',
    low: dark ? '#1C2B42' : '#DCE8F1', paper: dark ? '#30445F' : '#FFFAF0',
    paperLow: dark ? '#1C2B42' : '#DCE8F1', wood: dark ? '#6C4F3C' : '#D5AC7C',
    woodTop: dark ? '#9F7754' : '#F0D1A2', woodLow: dark ? '#6C4F3C' : '#D5AC7C',
    woodEdge: dark ? '#8E6B4F' : '#B58D65', woodInset: dark ? '#4C3E34' : '#EAD3AF',
    navy: '#20364F', blue: '#438ADF', coral: '#EB857C', gold: '#EABB63', mint: '#6CBFA4',
    violet: '#9988D3', cyan: '#4AA3BF', white: '#FFF8E7' };
}
function gradients(theme) {
  const p = palette(theme), dark = theme === 'dark';
  return gradient('paper', p.paper, p.low) + gradient('blue', '#9AD2F7', '#397ACB') +
    gradient('coral', '#FFC0A5', '#CF645F') + gradient('gold', '#FFE7AD', '#D7A04A') +
    gradient('mint', '#B7EACD', '#4D9E85') + gradient('violet', '#DCD2FA', '#8470C2') +
    gradient('cyan', '#B8EDF1', '#4AA3BF') + gradient('wood', p.woodTop, p.wood) +
    gradient('metal', '#DBEAF2', '#6386A8') + gradient('ink', '#62788E', '#20364F') +
    gradient('ivory', '#FFF8E7', '#C9D8E6') + gradient('darkstone', '#62788E', '#20364F') +
    gradient('whitestone', '#FFF8E7', '#C9D8E6') +
    gradient('jade', dark ? '#3A655C' : '#B7EACD', dark ? '#223F3C' : '#6CBFA4') +
    gradient('night', '#30445F', '#1C2B42') + gradient('glow', '#FFE7AD', '#EABB63') +
    gradient('tile', p.paper, p.low);
}
function resourceColors(theme) {
  const p = palette(theme), dark = theme === 'dark';
  const colors = { play_board_background:p.low, play_cell_background:p.paper,
    play_cell_alternate:dark?'#243851':'#EEF5F7', play_selection_background:dark?'#284967':'#BFDDF3',
    play_success_background:dark?'#285246':'#CBE6D8', play_piece_text:p.ink,
    play_fixed_digit:dark?'#EABB63':'#8C5D2C', play_piece_border:p.edge,
    play_color_piece_text:'#20364F', play_mine_revealed_background:dark?'#5B3D45':'#F1C7BD',
    tile_text_low:'#20364F', tile_text_high:'#20364F', tile_large:'#BDA5DF' };
  const shapes = dark ? ['#F0B3A4','#EBCF9C','#A6D8BF','#A0C8E8','#C1B4E6','#E5BAD0','#A4D7DD'] :
    ['#ECA291','#E4C18A','#91CBB0','#82B5D9','#B1A1D8','#D8A3BF','#8CC9D2'];
  shapes.forEach((color,i)=>{colors['shape_'+(i+1)]=color;});
  const tiles = ['#FFE7AD','#FFD0BC','#ADD5EF','#B7EACD','#DCD2FA','#B8EDF1','#E6C98F','#E4A395','#8CB9E0','#91CBAE','#D7AE65'];
  tiles.forEach((color,i)=>{colors['tile_'+Math.pow(2,i+1)]=color;});
  const numbers = dark ? ['#8FBCE5','#8FC5A8','#E6A098','#B7A6E0','#D3AE8D','#8DC7D0','#D9E7F2','#B1C1D3'] :
    ['#3971A0','#447B60','#A45150','#6B5798','#905C44','#327783','#304A69','#657D93'];
  numbers.forEach((color,i)=>{colors['mine_num_'+(i+1)]=color;});
  [p.coral,p.gold,p.mint,p.cyan,p.violet].forEach((color,i)=>{colors['brick_row_'+i]=color;});
  return colors;
}
module.exports = { palette, gradients, resourceColors };
