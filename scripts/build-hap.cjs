/* Build with DevEco Studio API 26; environment changes stay in the child process. */
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const root = path.resolve(__dirname, '..');
const studio = 'C:/Program Files/Huawei/DevEco Studio';
const commandLineTools = process.env.LITTLEGAMES_TOOLCHAIN_ROOT;
const toolchain = path.resolve(commandLineTools || studio);
const tools = commandLineTools ? toolchain : path.join(toolchain, 'tools');
const javaHome = process.env.JAVA_HOME || path.join(studio, 'jbr');
const mode = process.argv[2] || 'debug';
if (mode !== 'debug' && mode !== 'release') {
  throw new Error('Usage: node scripts/build-hap.cjs [debug|release]');
}
const sdk = JSON.parse(fs.readFileSync(path.join(toolchain, 'sdk/default/sdk-pkg.json'), 'utf8'));
if (sdk.data.apiVersion !== '26') {
  throw new Error('Expected HarmonyOS API 26 SDK, found ' + sdk.data.apiVersion);
}
const nodeHome = path.join(tools, commandLineTools ? 'tool/node' : 'node');
const packageBin = commandLineTools ? path.join(tools, 'bin') : path.join(tools, 'ohpm/bin');
const env = {
  ...process.env,
  HVIGOR_USER_HOME: path.join(root, '.local-tools/hvigor-user-home'),
  DEVECO_SDK_HOME: path.join(toolchain, 'sdk'),
  DEVECO_NODE_HOME: nodeHome,
  JAVA_HOME: javaHome,
  PATH: [nodeHome, packageBin, path.join(javaHome, 'bin'), process.env.PATH].join(path.delimiter)
};
const result = cp.spawnSync(path.join(nodeHome, 'node.exe'), [path.join(tools, 'hvigor/bin/hvigorw.js'),
  'assembleHap', '--mode', 'module', '-p', 'product=default', '-p', 'buildMode=' + mode,
  '--no-daemon', '--no-incremental'], { cwd: root, env, stdio: 'inherit' });
if (result.error) { throw result.error; }
process.exitCode = result.status === null ? 1 : result.status;
