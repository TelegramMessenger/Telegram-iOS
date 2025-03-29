import localforage from 'localforage';
import log from './logger.js';
import { instantiateAny } from './wasm-utils.js';

import td_wasm_release from './prebuilt/release/td_wasm.wasm';

const tdlibVersion = 6;
const localForageDrivers = [
  localforage.INDEXEDDB,
  localforage.LOCALSTORAGE,
  'memoryDriver'
];

async function initLocalForage() {
  // Implement the driver here.
  const memoryDriver = {
    _driver: 'memoryDriver',
    _initStorage: function(options) {
      const dbInfo = {};
      if (options) {
        for (const i in options) {
          dbInfo[i] = options[i];
        }
      }
      this._dbInfo = dbInfo;
      this._map = new Map();
    },
    clear: async function() {
      this._map.clear();
    },
    getItem: async function(key) {
      const value = this._map.get(key);
      console.log('getItem', this._map, key, value);
      return value;
    },
    iterate: async function(iteratorCallback) {
      log.error('iterate is not supported');
    },
    key: async function(n) {
      log.error('key n is not supported');
    },
    keys: async function() {
      return this._map.keys();
    },
    length: async function() {
      return this._map.size();
    },
    removeItem: async function(key) {
      this._map.delete(key);
    },
    setItem: async function(key, value) {
      const originalValue = this._map.get(key);
      console.log('setItem', this._map, key, value);
      this._map.set(key, value);
      return originalValue;
    }
  };

  // Add the driver to localForage.
  localforage.defineDriver(memoryDriver);
}

async function loadTdlibWasm(onFS, wasmUrl) {
  console.log('loadTdlibWasm');
  const td_module = await import('./prebuilt/release/td_wasm.js');
  const createTdwebModule = td_module.default;
  log.info('receive td_wasm.js', td_module, createTdwebModule);
  let td_wasm = td_wasm_release;
  if (wasmUrl) {
    td_wasm = wasmUrl;
  }
  let module = createTdwebModule({
    onRuntimeInitialized: () => {
      log.info('runtime intialized');
      onFS(module.FS);
    },
    instantiateWasm: (imports, successCallback) => {
      log.info('start instantiateWasm', td_wasm, imports);
      const next = instance => {
        log.info('finish instantiateWasm');
        successCallback(instance);
      };
      instantiateAny(tdlibVersion, td_wasm, imports).then(next);
      return {};
    }
  });
  log.info('Wait module');
  module = await module;
  log.info('Loaded module', module);
  //onFS(module.FS);
  return module;
}

async function loadTdlib(onFS, wasmUrl) {
  const wasmSupported = (() => {
    try {
      if (
        typeof WebAssembly === 'object' &&
        typeof WebAssembly.instantiate === 'function'
      ) {
        const module = new WebAssembly.Module(
          Uint8Array.of(0x0, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00)
        );
        if (module instanceof WebAssembly.Module)
          return (
            new WebAssembly.Instance(module) instanceof WebAssembly.Instance
          );
      }
    } catch (e) {}
    return false;
  })();
  if (!wasmSupported) {
    log.error('WebAssembly is not supported, trying to use it anyway');
  }

  return loadTdlibWasm(onFS, wasmUrl);
}

class OutboundFileSystem {
  constructor(root, FS) {
    this.root = root;
    this.nextFileId = 0;
    this.FS = FS;
    this.files = new Set();
    FS.mkdir(root);
  }
  blobToPath(blob, name) {
    const dir = this.root + '/' + this.nextFileId;
    if (!name) {
      name = 'blob';
    }
    this.nextFileId++;
    this.FS.mkdir(dir);
    this.FS.mount(
      this.FS.filesystems.WORKERFS,
      {
        blobs: [{ name: name, data: blob }]
      },
      dir
    );
    const path = dir + '/' + name;
    this.files.add(path);
    return path;
  }

  forgetPath(path) {
    if (this.files.has(path)) {
      this.FS.unmount(path);
      this.files.delete(path);
    }
  }
}

class InboundFileSystem {
  static async create(dbName, root, FS_promise) {
    const start = performance.now();
    try {
      const ifs = new InboundFileSystem();
      ifs.pending = [];
      ifs.pendingHasTimeout = false;
      ifs.persistCount = 0;
      ifs.persistSize = 0;
      ifs.pendingI = 0;
      ifs.inPersist = false;
      ifs.totalCount = 0;

      ifs.root = root;

      //ifs.store = localforage.createInstance({
      //name: dbName,
      //driver: localForageDrivers
      //});
      log.debug('IDB name: ' + dbName);
      ifs.idb = new Promise((resolve, reject) => {
        const request = indexedDB.open(dbName);
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
        request.onupgradeneeded = () => {
          request.result.createObjectStore('keyvaluepairs');
        };
      });

      ifs.load_pids();

      const FS = await FS_promise;
      await ifs.idb;
      ifs.FS = FS;
      ifs.FS.mkdir(root);
      const create_time = (performance.now() - start) / 1000;
      log.debug('InboundFileSystem::create ' + create_time);
      return ifs;
    } catch (e) {
      log.error('Failed to init Inbound FileSystem: ', e);
    }
  }

  async load_pids() {
    const keys_start = performance.now();
    log.debug('InboundFileSystem::create::keys start');
    //const keys = await this.store.keys();

    let idb = await this.idb;
    let read = idb
      .transaction(['keyvaluepairs'], 'readonly')
      .objectStore('keyvaluepairs');
    const keys = await new Promise((resolve, reject) => {
      const request = read.getAllKeys();
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });

    const keys_time = (performance.now() - keys_start) / 1000;
    log.debug(
      'InboundFileSystem::create::keys ' + keys_time + ' ' + keys.length
    );
    this.pids = new Set(keys);
  }

  has(pid) {
    if (!this.pids) {
      return true;
    }

    return this.pids.has(pid);
  }

  forget(pid) {
    if (this.pids) {
      this.pids.delete(pid);
    }
  }

  async doPersist(pid, path, arr, resolve, reject, write) {
    this.persistCount++;
    let size = arr.length;
    this.persistSize += size;
    try {
      //log.debug('persist.do start', pid, path, arr.length);
      //await this.store.setItem(pid, new Blob([arr]));
      await new Promise((resolve, reject) => {
        const request = write.put(new Blob([arr]), pid);
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
      });
      if (this.pids) {
        this.pids.add(pid);
      }
      this.FS.unlink(path);
    } catch (e) {
      log.error('Failed persist ' + path + ' ', e);
    }
    //log.debug('persist.do finish', pid, path, arr.length);
    this.persistCount--;
    this.persistSize -= size;
    resolve();

    this.tryFinishPersist();
  }

  async flushPersist() {
    if (this.inPersist) {
      return;
    }
    log.debug('persist.flush');
    this.inPersist = true;
    let idb = await this.idb;
    this.writeBegin = performance.now();
    let write = idb
      .transaction(['keyvaluepairs'], 'readwrite')
      .objectStore('keyvaluepairs');
    while (
      this.pendingI < this.pending.length &&
      this.persistCount < 20 &&
      this.persistSize < 50 << 20
    ) {
      var q = this.pending[this.pendingI];
      this.pending[this.pendingI] = null;
      // TODO: add to transaction
      this.doPersist(q.pid, q.path, q.arr, q.resolve, q.reject, write);
      this.pendingI++;
      this.totalCount++;
    }
    log.debug(
      'persist.flush transaction cnt=' +
        this.persistCount +
        ', size=' +
        this.persistSize
    );
    this.inPersist = false;
    this.tryFinishPersist();
  }

  async tryFinishPersist() {
    if (this.inPersist) {
      return;
    }
    if (this.persistCount !== 0) {
      return;
    }
    log.debug('persist.finish ' + (performance.now() - this.writeBegin) / 1000);
    if (this.pendingI === this.pending.length) {
      this.pending = [];
      this.pendingHasTimeout = false;
      this.pendingI = 0;
      log.debug('persist.finish done');
      return;
    }
    log.debug('persist.finish continue');
    this.flushPersist();
  }

  async persist(pid, path, arr) {
    if (!this.pendingHasTimeout) {
      this.pendingHasTimeout = true;
      log.debug('persist set timeout');
      setTimeout(() => {
        this.flushPersist();
      }, 1);
    }
    await new Promise((resolve, reject) => {
      this.pending.push({
        pid: pid,
        path: path,
        arr: arr,
        resolve: resolve,
        reject: reject
      });
    });
  }

  async unlink(pid) {
    log.debug('Unlink ' + pid);
    try {
      this.forget(pid);
      //await this.store.removeItem(pid);
      let idb = await this.idb;
      await new Promise((resolve, reject) => {
        let write = idb
          .transaction(['keyvaluepairs'], 'readwrite')
          .objectStore('keyvaluepairs');
        const request = write.delete(pid);
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
      });
    } catch (e) {
      log.error('Failed unlink ' + pid + ' ', e);
    }
  }
}

class DbFileSystem {
  static async create(root, FS_promise, readOnly = false) {
    const start = performance.now();
    try {
      const dbfs = new DbFileSystem();
      dbfs.root = root;
      const FS = await FS_promise;
      dbfs.FS = FS;
      dbfs.syncfs_total_time = 0;
      dbfs.readOnly = readOnly;
      dbfs.syncActive = 0;
      FS.mkdir(root);
      FS.mount(FS.filesystems.IDBFS, {}, root);

      await new Promise((resolve, reject) => {
        FS.syncfs(true, err => {
          resolve();
        });
      });

      const rmrf = path => {
        log.debug('rmrf ', path);
        let info;
        try {
          info = FS.lookupPath(path);
        } catch (e) {
          return;
        }
        log.debug('rmrf ', path, info);
        if (info.node.isFolder) {
          for (const key in info.node.contents) {
            rmrf(info.path + '/' + info.node.contents[key].name);
          }
          log.debug('rmdir ', path);
          FS.rmdir(path);
        } else {
          log.debug('unlink ', path);
          FS.unlink(path);
        }
      };
      //const dirs = ['thumbnails', 'profile_photos', 'secret', 'stickers', 'temp', 'wallpapers', 'secret_thumbnails', 'passport'];
      const dirs = [];
      const root_dir = FS.lookupPath(root);
      for (const key in root_dir.node.contents) {
        const value = root_dir.node.contents[key];
        log.debug('node ', key, value);
        if (!value.isFolder) {
          continue;
        }
        dirs.push(root_dir.path + '/' + value.name);
      }
      for (const i in dirs) {
        const dir = dirs[i];
        rmrf(dir);
        //FS.mkdir(dir);
        //FS.mount(FS.filesystems.MEMFS, {}, dir);
      }
      dbfs.syncfsInterval = setInterval(() => {
        dbfs.sync();
      }, 5000);
      const create_time = (performance.now() - start) / 1000;
      log.debug('DbFileSystem::create ' + create_time);
      return dbfs;
    } catch (e) {
      log.error('Failed to init DbFileSystem: ', e);
    }
  }
  async sync(force) {
    if (this.readOnly) {
      return;
    }
    if (this.syncActive > 0 && !force) {
      log.debug('SYNC: skip');
      return;
    }
    this.syncActive++;
    const start = performance.now();
    await new Promise((resolve, reject) => {
      this.FS.syncfs(false, () => {
        const syncfs_time = (performance.now() - start) / 1000;
        this.syncfs_total_time += syncfs_time;
        log.debug('SYNC: ' + syncfs_time);
        log.debug('SYNC total: ' + this.syncfs_total_time);
        resolve();
      });
    });
    this.syncActive--;
  }
  async close() {
    clearInterval(this.syncfsInterval);
    await this.sync(true);
  }
  async destroy() {
    clearInterval(this.syncfsInterval);
    if (this.readOnly) {
      return;
    }
    this.FS.unmount(this.root);
    const req = indexedDB.deleteDatabase(this.root);
    await new Promise((resolve, reject) => {
      req.onsuccess = function(e) {
        log.info('SUCCESS');
        resolve(e.result);
      };
      req.onerror = function(e) {
        log.info('ONERROR');
        reject(e.error);
      };
      req.onblocked = function(e) {
        log.info('ONBLOCKED');
        reject('blocked');
      };
    });
  }
}

class TdFileSystem {
  static async init_fs(prefix, FS_promise) {
    const FS = await FS_promise;
    FS.mkdir(prefix);
    return FS;
  }
  static async create(instanceName, FS_promise, readOnly = false) {
    try {
      const tdfs = new TdFileSystem();
      const prefix = '/' + instanceName;
      tdfs.prefix = prefix;
      FS_promise = TdFileSystem.init_fs(prefix, FS_promise);

      //MEMFS. Store to IDB and delete files as soon as possible
      const inboundFileSystem = InboundFileSystem.create(
        instanceName,
        prefix + '/inboundfs',
        FS_promise
      );

      //IDBFS. MEMFS which is flushed to IDB from time to time
      const dbFileSystem = DbFileSystem.create(
        prefix + '/dbfs',
        FS_promise,
        readOnly
      );

      const FS = await FS_promise;
      tdfs.FS = FS;

      //WORKERFS. Temporary stores Blobs for outbound files
      tdfs.outboundFileSystem = new OutboundFileSystem(
        prefix + '/outboundfs',
        tdfs.FS
      );

      tdfs.inboundFileSystem = await inboundFileSystem;
      tdfs.dbFileSystem = await dbFileSystem;
      return tdfs;
    } catch (e) {
      log.error('Failed to init TdFileSystem: ', e);
    }
  }
  async destroy() {
    await this.dbFileSystem.destroy();
  }
}

class TdClient {
  constructor(callback) {
    log.info('Start worker');
    this.pendingQueries = [];
    this.isPending = true;
    this.callback = callback;
    this.wasInit = false;
  }

  async testLocalForage() {
    await initLocalForage();
    const DRIVERS = [
      localforage.INDEXEDDB,
      'memoryDriver',
      localforage.LOCALSTORAGE,
      localforage.WEBSQL,
      localForageDrivers
    ];
    for (const driverName of DRIVERS) {
      console.log('Test ', driverName);
      try {
        await localforage.setDriver(driverName);
        console.log('A');
        await localforage.setItem('hello', 'world');
        console.log('B');
        const x = await localforage.getItem('hello');
        console.log('receive ', x);
        await localforage.clear();
        console.log('C');
      } catch (error) {
        console.log('Error', error);
      }
    }
  }

  async init(options) {
    if (this.wasInit) {
      return;
    }
    //await this.testLocalForage();
    log.setVerbosity(options.jsLogVerbosityLevel);
    this.wasInit = true;

    options = options || {};

    const FS_promise = new Promise(resolve => {
      this.onFS = resolve;
    });

    const tdfs_promise = TdFileSystem.create(
      options.instanceName,
      FS_promise,
      options.readOnly
    );

    this.useDatabase = true;
    if ('useDatabase' in options) {
      this.useDatabase = options.useDatabase;
    }

    log.info('load TdModule');
    this.TdModule = await loadTdlib(this.onFS, options.wasmUrl);
    log.info('loaded TdModule');
    this.td_functions = {
      td_create: this.TdModule.cwrap(
        'td_emscripten_create_client_id',
        'number',
        []
      ),
      td_send: this.TdModule.cwrap('td_emscripten_send', null, [
        'number',
        'string'
      ]),
      td_execute: this.TdModule.cwrap('td_emscripten_execute', 'string', [
        'string'
      ]),
      td_receive: this.TdModule.cwrap('td_emscripten_receive', 'string', []),
      td_set_verbosity: verbosity => {
        this.td_functions.td_execute(
          JSON.stringify({
            '@type': 'setLogVerbosityLevel',
            new_verbosity_level: verbosity
          })
        );
      },
      td_get_timeout: this.TdModule.cwrap(
        'td_emscripten_get_timeout',
        'number',
        []
      )
    };
    //this.onFS(this.TdModule.FS);
    this.FS = this.TdModule.FS;
    this.TdModule['websocket']['on']('error', error => {
      this.scheduleReceiveSoon();
    });
    this.TdModule['websocket']['on']('open', fd => {
      this.scheduleReceiveSoon();
    });
    this.TdModule['websocket']['on']('listen', fd => {
      this.scheduleReceiveSoon();
    });
    this.TdModule['websocket']['on']('connection', fd => {
      this.scheduleReceiveSoon();
    });
    this.TdModule['websocket']['on']('message', fd => {
      this.scheduleReceiveSoon();
    });
    this.TdModule['websocket']['on']('close', fd => {
      this.scheduleReceiveSoon();
    });

    // wait till it is allowed to start
    this.callback({ '@type': 'inited' });
    await new Promise(resolve => {
      this.onStart = resolve;
    });
    this.isStarted = true;

    log.info('may start now');
    if (this.isClosing) {
      return;
    }
    log.info('FS start init');
    this.tdfs = await tdfs_promise;
    log.info('FS inited');
    this.callback({ '@type': 'fsInited' });

    // no async initialization after this point
    if (options.logVerbosityLevel === undefined) {
      options.logVerbosityLevel = 2;
    }
    this.td_functions.td_set_verbosity(options.logVerbosityLevel);
    this.client_id = this.td_functions.td_create();

    this.savingFiles = new Map();
    this.send({
      '@type': 'setOption',
      name: 'store_all_files_in_files_directory',
      value: {
        '@type': 'optionValueBoolean',
        value: true
      }
    });
    this.send({
      '@type': 'setOption',
      name: 'language_pack_database_path',
      value: {
        '@type': 'optionValueString',
        value: this.tdfs.dbFileSystem.root + '/language'
      }
    });
    this.send({
      '@type': 'setOption',
      name: 'ignore_background_updates',
      value: {
        '@type': 'optionValueBoolean',
        value: !this.useDatabase
      }
    });

    this.flushPendingQueries();

    this.receive();
  }

  prepareQueryRecursive(query) {
    if (query['@type'] === 'inputFileBlob') {
      return {
        '@type': 'inputFileLocal',
        path: this.tdfs.outboundFileSystem.blobToPath(query.data, query.name)
      };
    }
    for (const key in query) {
      const field = query[key];
      if (field && typeof field === 'object') {
        query[key] = this.prepareQueryRecursive(field);
      }
    }
    return query;
  }

  prepareQuery(query) {
    if (query['@type'] === 'setTdlibParameters') {
      query.database_directory = this.tdfs.dbFileSystem.root;
      query.files_directory = this.tdfs.inboundFileSystem.root;

      const useDb = this.useDatabase;
      query.use_file_database = useDb;
      query.use_chat_info_database = useDb;
      query.use_message_database = useDb;
      query.use_secret_chats = useDb;
    }
    if (query['@type'] === 'getLanguagePackString') {
      query.language_pack_database_path =
        this.tdfs.dbFileSystem.root + '/language';
    }
    return this.prepareQueryRecursive(query);
  }

  onStart() {
    //nop
    log.info('ignore on_start');
  }

  deleteIdbKey(query) {
    try {
    } catch (e) {
      this.callback({
        '@type': 'error',
        '@extra': query['@extra'],
        code: 400,
        message: e
      });
      return;
    }
    this.callback({
      '@type': 'ok',
      '@extra': query['@extra']
    });
  }

  readFilePart(query) {
    let res;
    try {
      //const file_size = this.FS.stat(query.path).size;
      const stream = this.FS.open(query.path, 'r');
      const buf = new Uint8Array(query.count);
      this.FS.read(stream, buf, 0, query.count, query.offset);
      this.FS.close(stream);
      res = buf;
    } catch (e) {
      this.callback({
        '@type': 'error',
        '@extra': query['@extra'],
        code: 400,
        message: e.toString()
      });
      return;
    }
    this.callback(
      {
        '@type': 'filePart',
        '@extra': query['@extra'],
        data: res
      },
      [res.buffer]
    );
  }

  send(query) {
    if (this.isClosing) {
      return;
    }
    if (this.wasFatalError) {
      if (query['@type'] === 'destroy') {
        this.destroy({ '@type': 'ok', '@extra': query['@extra'] });
      }
      return;
    }
    if (query['@type'] === 'init') {
      this.init(query.options);
      return;
    }
    if (query['@type'] === 'start') {
      log.info('on_start');
      this.onStart();
      return;
    }
    if (query['@type'] === 'setJsLogVerbosityLevel') {
      log.setVerbosity(query.new_verbosity_level);
      return;
    }
    if (this.isPending) {
      this.pendingQueries.push(query);
      return;
    }
    if (
      query['@type'] === 'setLogVerbosityLevel' ||
      query['@type'] === 'getLogVerbosityLevel' ||
      query['@type'] === 'setLogTagVerbosityLevel' ||
      query['@type'] === 'getLogTagVerbosityLevel' ||
      query['@type'] === 'getLogTags'
    ) {
      this.execute(query);
      return;
    }
    if (query['@type'] === 'readFilePart') {
      this.readFilePart(query);
      return;
    }
    if (query['@type'] === 'deleteIdbKey') {
      this.deleteIdbKey(query);
      return;
    }
    query = this.prepareQuery(query);
    this.td_functions.td_send(this.client_id, JSON.stringify(query));
    this.scheduleReceiveSoon();
  }

  execute(query) {
    try {
      const res = this.td_functions.td_execute(JSON.stringify(query));
      const response = JSON.parse(res);
      this.callback(response);
    } catch (error) {
      this.onFatalError(error);
    }
  }
  receive() {
    this.cancelReceive();
    if (this.wasFatalError) {
      return;
    }
    try {
      while (true) {
        const msg = this.td_functions.td_receive();
        if (!msg) {
          break;
        }
        const response = this.prepareResponse(JSON.parse(msg));
        if (
          response['@type'] === 'updateAuthorizationState' &&
          response.authorization_state['@type'] === 'authorizationStateClosed'
        ) {
          this.close(response);
          break;
        }
        this.callback(response);
      }

      this.scheduleReceive();
    } catch (error) {
      this.onFatalError(error);
    }
  }

  cancelReceive() {
    if (this.receiveTimeout) {
      clearTimeout(this.receiveTimeout);
      delete this.receiveTimeout;
    }
    delete this.receiveSoon;
  }
  scheduleReceiveSoon() {
    if (this.receiveSoon) {
      return;
    }
    this.cancelReceive();
    this.receiveSoon = true;
    this.scheduleReceiveIn(0.001);
  }
  scheduleReceive() {
    if (this.receiveSoon) {
      return;
    }
    this.cancelReceive();
    const timeout = this.td_functions.td_get_timeout();
    this.scheduleReceiveIn(timeout);
  }
  scheduleReceiveIn(timeout) {
    //return;
    log.debug('Scheduler receive in ' + timeout + 's');
    this.receiveTimeout = setTimeout(() => this.receive(), timeout * 1000);
  }

  onFatalError(error) {
    this.wasFatalError = true;
    this.asyncOnFatalError(error);
  }

  async close(last_update) {
    // close db and cancel all timers
    this.isClosing = true;
    if (this.isStarted) {
      log.debug('close worker: start');
      await this.tdfs.dbFileSystem.close();
      this.cancelReceive();
      log.debug('close worker: finish');
    }
    this.callback(last_update);
  }

  async destroy(result) {
    try {
      log.info('destroy tdfs ...');
      await this.tdfs.destroy();
      log.info('destroy tdfs ok');
    } catch (e) {
      log.error('Failed destroy', e);
    }
    this.callback(result);
    this.callback({
      '@type': 'updateAuthorizationState',
      authorization_state: {
        '@type': 'authorizationStateClosed'
      }
    });
  }

  async asyncOnFatalError(error) {
    await this.tdfs.dbFileSystem.sync();
    this.callback({ '@type': 'updateFatalError', error: error });
  }

  saveFile(pid, file) {
    const isSaving = this.savingFiles.has(pid);
    this.savingFiles.set(pid, file);
    if (isSaving) {
      return file;
    }
    try {
      const arr = this.FS.readFile(file.local.path);
      if (arr) {
        file = Object.assign({}, file);
        file.arr = arr;
        this.doSaveFile(pid, file, arr);
      }
    } catch (e) {
      log.error('Failed to readFile: ', e);
    }
    return file;
  }

  async doSaveFile(pid, file, arr) {
    await this.tdfs.inboundFileSystem.persist(pid, file.local.path, arr);
    file = this.savingFiles.get(pid);
    file.idb_key = pid;
    this.callback({ '@type': 'updateFile', file: file });

    this.savingFiles.delete(pid);
  }

  prepareFile(file) {
    const pid = file.remote.unique_id ? file.remote.unique_id : file.remote.id;
    if (!pid) {
      return file;
    }

    if (file.local.is_downloading_active) {
      this.tdfs.inboundFileSystem.forget(pid);
    } else if (this.tdfs.inboundFileSystem.has(pid)) {
      file.idb_key = pid;
      return file;
    }

    if (file.local.is_downloading_completed) {
      file = this.saveFile(pid, file);
    }
    return file;
  }

  prepareResponse(response) {
    if (response['@type'] === 'file') {
      return this.prepareFile(response);
    }
    for (const key in response) {
      const field = response[key];
      if (field && typeof field === 'object') {
        response[key] = this.prepareResponse(field);
      }
    }
    return response;
  }

  flushPendingQueries() {
    this.isPending = false;
    for (const query of this.pendingQueries) {
      this.send(query);
    }
  }
}

const client = new TdClient((e, t = []) => postMessage(e, t));

onmessage = function(e) {
  try {
    client.send(e.data);
  } catch (error) {
    client.onFatalError(error);
  }
};
