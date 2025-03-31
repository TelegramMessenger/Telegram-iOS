import MyWorker from './worker.js';
//import localforage from 'localforage';
import BroadcastChannel from 'broadcast-channel';
import uuid4 from 'uuid/v4';
import log from './logger.js';

const sleep = ms => new Promise(res => setTimeout(res, ms));

/**
 * TDLib in a browser
 *
 * TDLib can be compiled to WebAssembly using Emscripten compiler and used in a browser from JavaScript.
 * This is a convenient wrapper for TDLib in a browser which controls TDLib instance creation, handles interaction
 * with TDLib and manages a filesystem for persistent TDLib data.
 * TDLib instance is created in a Web Worker to run it in a separate thread.
 * TdClient just sends queries to the Web Worker and receives updates and results from it.
 * <br>
 * <br>
 * Differences from the TDLib JSON API:<br>
 * 1. Added the update <code>updateFatalError error:string = Update;</code> which is sent whenever TDLib encounters a fatal error.<br>
 * 2. Added the method <code>setJsLogVerbosityLevel new_verbosity_level:string = Ok;</code>, which allows to change the verbosity level of tdweb logging.<br>
 * 3. Added the possibility to use blobs as input files via the constructor <code>inputFileBlob data:<JavaScript blob> = InputFile;</code>.<br>
 * 4. The class <code>filePart</code> contains data as a JavaScript blob instead of a base64-encoded string.<br>
 * 5. The methods <code>getStorageStatistics</code>, <code>getStorageStatisticsFast</code>, <code>optimizeStorage</code>, and <code>addProxy</code> are not supported.<br>
 * <br>
 */
class TdClient {
  /**
   * @callback TdClient~updateCallback
   * @param {Object} update The update.
   */

  /**
   * Create TdClient.
   * @param {Object} options - Options for TDLib instance creation.
   * @param {TdClient~updateCallback} options.onUpdate - Callback for all incoming updates.
   * @param {string} [options.instanceName=tdlib] - Name of the TDLib instance. Currently, only one instance of TdClient with a given name is allowed. All but one instances with the same name will be automatically closed. Usually, the newest non-background instance is kept alive. Files will be stored in an IndexedDb table with the same name.
   * @param {boolean} [options.isBackground=false] - Pass true if the instance is opened from the background.
   * @param {string} [options.jsLogVerbosityLevel=info] - The initial verbosity level of the JavaScript part of the code (one of 'error', 'warning', 'info', 'log', 'debug').
   * @param {number} [options.logVerbosityLevel=2] - The initial verbosity level for the TDLib internal logging (0-1023).
   * @param {boolean} [options.useDatabase=true] - Pass false to use TDLib without database and secret chats. It significantly improves loading time, but some functionality is unavailable without the database.
   * @param {boolean} [options.readOnly=false] - For debug only. Pass true to open TDLib database in read-only mode
   */
  constructor(options) {
    log.setVerbosity(options.jsLogVerbosityLevel);
    this.worker = new MyWorker();
    this.worker.onmessage = e => {
      this.onResponse(e.data);
    };
    this.query_id = 0;
    this.query_callbacks = new Map();
    if ('onUpdate' in options) {
      this.onUpdate = options.onUpdate;
      delete options.onUpdate;
    }
    options.instanceName = options.instanceName || 'tdlib';
    this.fileManager = new FileManager(options.instanceName, this);
    this.worker.postMessage({ '@type': 'init', options: options });
    this.closeOtherClients(options);
  }

  /**
   * Send a query to TDLib.
   *
   * If the query contains the field '@extra', the same field will be added into the result.
   *
   * @param {Object} query - The query for TDLib. See the [td_api.tl]{@link https://github.com/tdlib/td/blob/master/td/generate/scheme/td_api.tl} scheme or
   *                         the automatically generated [HTML documentation]{@link https://core.telegram.org/tdlib/docs/td__api_8h.html}
   *                         for a list of all available TDLib [methods]{@link https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1_function.html} and
   *                         [classes]{@link https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1_object.html}.
   * @returns {Promise} Promise object represents the result of the query.
   */
  send(query) {
    return this.doSend(query, true);
  }

  /** @private */
  sendInternal(query) {
    return this.doSend(query, false);
  }
  /** @private */
  doSend(query, isExternal) {
    this.query_id++;
    if (query['@extra']) {
      query['@extra'] = {
        '@old_extra': JSON.parse(JSON.stringify(query['@extra'])),
        query_id: this.query_id
      };
    } else {
      query['@extra'] = {
        query_id: this.query_id
      };
    }
    if (query['@type'] === 'setJsLogVerbosityLevel') {
      log.setVerbosity(query.new_verbosity_level);
    }

    log.debug('send to worker: ', query);
    const res = new Promise((resolve, reject) => {
      this.query_callbacks.set(this.query_id, [resolve, reject]);
    });
    if (isExternal) {
      this.externalPostMessage(query);
    } else {
      this.worker.postMessage(query);
    }
    return res;
  }

  /** @private */
  externalPostMessage(query) {
    const unsupportedMethods = [
      'getStorageStatistics',
      'getStorageStatisticsFast',
      'optimizeStorage',
      'addProxy',
      'init',
      'start'
    ];
    if (unsupportedMethods.includes(query['@type'])) {
      this.onResponse({
        '@type': 'error',
        '@extra': query['@extra'],
        code: 400,
        message: "Method '" + query['@type'] + "' is not supported"
      });
      return;
    }
    if (query['@type'] === 'readFile' || query['@type'] === 'readFilePart') {
      this.readFile(query);
      return;
    }
    if (query['@type'] === 'deleteFile') {
      this.deleteFile(query);
      return;
    }
    this.worker.postMessage(query);
  }

  /** @private */
  async readFile(query) {
    const response = await this.fileManager.readFile(query);
    this.onResponse(response);
  }

  /** @private */
  async deleteFile(query) {
    const response = this.fileManager.deleteFile(query);
    try {
      if (response.idb_key) {
        await this.sendInternal({
          '@type': 'deleteIdbKey',
          idb_key: response.idb_key
        });
        delete response.idb_key;
      }
      await this.sendInternal({
        '@type': 'deleteFile',
        file_id: query.file_id
      });
    } catch (e) {}
    this.onResponse(response);
  }

  /** @private */
  onResponse(response) {
    log.debug(
      'receive from worker: ',
      JSON.parse(
        JSON.stringify(response, (key, value) => {
          if (key === 'arr' || key === 'data') {
            return undefined;
          }
          return value;
        })
      )
    );

    // for FileManager
    response = this.prepareResponse(response);

    if ('@extra' in response) {
      const query_id = response['@extra'].query_id;
      const [resolve, reject] = this.query_callbacks.get(query_id);
      this.query_callbacks.delete(query_id);
      if ('@old_extra' in response['@extra']) {
        response['@extra'] = response['@extra']['@old_extra'];
      }
      if (resolve) {
        if (response['@type'] === 'error') {
          reject(response);
        } else {
          resolve(response);
        }
      }
    } else {
      if (response['@type'] === 'inited') {
        this.onInited();
        return;
      }
      if (response['@type'] === 'fsInited') {
        this.onFsInited();
        return;
      }
      if (
        response['@type'] === 'updateAuthorizationState' &&
        response.authorization_state['@type'] === 'authorizationStateClosed'
      ) {
        this.onClosed();
      }
      this.onUpdate(response);
    }
  }

  /** @private */
  prepareFile(file) {
    return this.fileManager.registerFile(file);
  }

  /** @private */
  prepareResponse(response) {
    if (response['@type'] === 'file') {
      if (false && Math.random() < 0.1) {
        (async () => {
          log.warn('DELETE FILE', response.id);
          try {
            await this.send({ '@type': 'deleteFile', file_id: response.id });
          } catch (e) {}
        })();
      }
      return this.prepareFile(response);
    }
    for (const key in response) {
      const field = response[key];
      if (
        field &&
        typeof field === 'object' &&
        key !== 'data' &&
        key !== 'arr'
      ) {
        response[key] = this.prepareResponse(field);
      }
    }
    return response;
  }

  /** @private */
  onBroadcastMessage(e) {
    //const message = e.data;
    const message = e;
    if (message.uid === this.uid) {
      log.info('ignore self broadcast message: ', message);
      return;
    }
    log.info('receive broadcast message: ', message);
    if (message.isBackground && !this.isBackground) {
      // continue
    } else if (
      (!message.isBackground && this.isBackground) ||
      message.timestamp > this.timestamp
    ) {
      this.close();
      return;
    }
    if (message.state === 'closed') {
      this.waitSet.delete(message.uid);
      if (this.waitSet.size === 0) {
        log.info('onWaitSetEmpty');
        this.onWaitSetEmpty();
        this.onWaitSetEmpty = () => {};
      }
    } else {
      this.waitSet.add(message.uid);
      if (message.state !== 'closing') {
        this.postState();
      }
    }
  }

  /** @private */
  postState() {
    const state = {
      uid: this.uid,
      state: this.state,
      timestamp: this.timestamp,
      isBackground: this.isBackground
    };
    log.info('Post state: ', state);
    this.channel.postMessage(state);
  }

  /** @private */
  onWaitSetEmpty() {
    // nop
  }

  /** @private */
  onFsInited() {
    this.fileManager.init();
  }

  /** @private */
  onInited() {
    this.isInited = true;
    this.doSendStart();
  }

  /** @private */
  sendStart() {
    this.wantSendStart = true;
    this.doSendStart();
  }

  /** @private */
  doSendStart() {
    if (!this.isInited || !this.wantSendStart || this.state !== 'start') {
      return;
    }
    this.wantSendStart = false;
    this.state = 'active';
    const query = { '@type': 'start' };
    log.info('send to worker: ', query);
    this.worker.postMessage(query);
  }

  /** @private */
  onClosed() {
    this.isClosing = true;
    this.worker.terminate();
    log.info('worker is terminated');
    this.state = 'closed';
    this.postState();
  }

  /** @private */
  close() {
    if (this.isClosing) {
      return;
    }
    this.isClosing = true;

    log.info('close state: ', this.state);

    if (this.state === 'start') {
      this.onClosed();
      this.onUpdate({
        '@type': 'updateAuthorizationState',
        authorization_state: {
          '@type': 'authorizationStateClosed'
        }
      });
      return;
    }

    const query = { '@type': 'close' };
    log.info('send to worker: ', query);
    this.worker.postMessage(query);

    this.state = 'closing';
    this.postState();
  }

  /** @private */
  async closeOtherClients(options) {
    this.uid = uuid4();
    this.state = 'start';
    this.isBackground = !!options.isBackground;
    this.timestamp = Date.now();
    this.waitSet = new Set();

    log.info('close other clients');
    this.channel = new BroadcastChannel(options.instanceName, {
      webWorkerSupport: false
    });

    this.postState();

    this.channel.onmessage = message => {
      this.onBroadcastMessage(message);
    };

    await sleep(300);
    if (this.waitSet.size !== 0) {
      await new Promise(resolve => {
        this.onWaitSetEmpty = resolve;
      });
    }
    this.sendStart();
  }

  /** @private */
  onUpdate(update) {
    log.info('ignore onUpdate');
    //nop
  }
}

/** @private */
class ListNode {
  constructor(value) {
    this.value = value;
    this.clear();
  }

  erase() {
    this.prev.connect(this.next);
    this.clear();
  }
  clear() {
    this.prev = this;
    this.next = this;
  }

  connect(other) {
    this.next = other;
    other.prev = this;
  }

  onUsed(other) {
    other.usedAt = Date.now();
    other.erase();
    other.connect(this.next);
    log.debug('LRU: used file_id: ', other.value);
    this.connect(other);
  }

  getLru() {
    if (this === this.next) {
      throw new Error('popLru from empty list');
    }
    return this.prev;
  }
}

/** @private */
class FileManager {
  constructor(instanceName, client) {
    this.instanceName = instanceName;
    this.cache = new Map();
    this.pending = [];
    this.transaction_id = 0;
    this.totalSize = 0;
    this.lru = new ListNode(-1);
    this.client = client;
  }

  init() {
    this.idb = new Promise((resolve, reject) => {
      const request = indexedDB.open(this.instanceName);
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
    //this.store = localforage.createInstance({
    //name: instanceName
    //});
    this.isInited = true;
  }

  unload(info) {
    if (info.arr) {
      log.debug(
        'LRU: delete file_id: ',
        info.node.value,
        ' with arr.length: ',
        info.arr.length
      );
      this.totalSize -= info.arr.length;
      delete info.arr;
    }
    if (info.node) {
      info.node.erase();
      delete info.node;
    }
  }

  registerFile(file) {
    if (file.idb_key || file.arr) {
      file.local.is_downloading_completed = true;
    } else {
      file.local.is_downloading_completed = false;
    }
    let info = {};
    const cached_info = this.cache.get(file.id);
    if (cached_info) {
      info = cached_info;
    } else {
      this.cache.set(file.id, info);
    }
    if (file.idb_key) {
      info.idb_key = file.idb_key;
      delete file.idb_key;
    } else {
      delete info.idb_key;
    }
    if (file.arr) {
      const now = Date.now();
      while (this.totalSize > 100000000) {
        const node = this.lru.getLru();
        // immunity for 60 seconds
        if (node.usedAt + 60 * 1000 > now) {
          break;
        }
        const lru_info = this.cache.get(node.value);
        this.unload(lru_info);
      }

      if (info.arr) {
        log.warn('Receive file.arr at least twice for the same file');
        this.totalSize -= info.arr.length;
      }
      info.arr = file.arr;
      delete file.arr;
      this.totalSize += info.arr.length;
      if (!info.node) {
        log.debug(
          'LRU: create file_id: ',
          file.id,
          ' with arr.length: ',
          info.arr.length
        );
        info.node = new ListNode(file.id);
      }
      this.lru.onUsed(info.node);
      log.info('Total file.arr size: ', this.totalSize);
    }
    info.file = file;
    return file;
  }

  async flushLoad() {
    const pending = this.pending;
    this.pending = [];
    const idb = await this.idb;
    const transaction_id = this.transaction_id++;
    const read = idb
      .transaction(['keyvaluepairs'], 'readonly')
      .objectStore('keyvaluepairs');
    log.debug('Load group of files from idb', pending.length);
    for (const query of pending) {
      const request = read.get(query.key);
      request.onsuccess = event => {
        const blob = event.target.result;
        if (blob) {
          if (blob.size === 0) {
            log.error('Receive empty blob from db ', query.key);
          }
          query.resolve({ data: blob, transaction_id: transaction_id });
        } else {
          query.reject();
        }
      };
      request.onerror = () => query.reject(request.error);
    }
  }

  load(key, resolve, reject) {
    if (this.pending.length === 0) {
      setTimeout(() => {
        this.flushLoad();
      }, 1);
    }
    this.pending.push({ key: key, resolve: resolve, reject: reject });
  }

  async doLoadFull(info) {
    if (info.arr) {
      return { data: new Blob([info.arr]), transaction_id: -1 };
    }
    if (info.idb_key) {
      const idb_key = info.idb_key;
      //return this.store.getItem(idb_key);
      return await new Promise((resolve, reject) => {
        this.load(idb_key, resolve, reject);
      });
    }
    throw new Error('File is not loaded');
  }
  async doLoad(info, offset, size) {
    if (!info.arr && !info.idb_key && info.file.local.path) {
      try {
        const count = await this.client.sendInternal({
          '@type': 'getFileDownloadedPrefixSize',
          file_id: info.file.id,
          offset: offset
        });
        //log.error(count, size);
        if (!size) {
          size = count.count;
        } else if (size > count.count) {
          throw new Error('File not loaded yet');
        }
        const res = await this.client.sendInternal({
          '@type': 'readFilePart',
          path: info.file.local.path,
          offset: offset,
          count: size
        });
        res.data = new Blob([res.data]);
        res.transaction_id = -2;
        //log.error(res);
        return res;
      } catch (e) {
        log.info('readFilePart failed', info, offset, size, e);
      }
    }

    const res = await this.doLoadFull(info);

    // return slice(size, offset + size)
    const data_size = res.data.size;
    if (!size) {
      size = data_size;
    }
    if (offset > data_size) {
      offset = data_size;
    }
    res.data = res.data.slice(offset, offset + size);
    return res;
  }

  doDelete(info) {
    this.unload(info);
    return info.idb_key;
  }

  async readFile(query) {
    try {
      if (!this.isInited) {
        throw new Error('FileManager is not inited');
      }
      const info = this.cache.get(query.file_id);
      if (!info) {
        throw new Error('File is not loaded');
      }
      if (info.node) {
        this.lru.onUsed(info.node);
      }
      query.offset = query.offset || 0;
      query.size = query.count || query.size || 0;
      const response = await this.doLoad(info, query.offset, query.size);
      return {
        '@type': 'filePart',
        '@extra': query['@extra'],
        data: response.data,
        transaction_id: response.transaction_id
      };
    } catch (e) {
      return {
        '@type': 'error',
        '@extra': query['@extra'],
        code: 400,
        message: e
      };
    }
  }

  deleteFile(query) {
    const res = {
      '@type': 'ok',
      '@extra': query['@extra']
    };
    try {
      if (!this.isInited) {
        throw new Error('FileManager is not inited');
      }
      const info = this.cache.get(query.file_id);
      if (!info) {
        throw new Error('File is not loaded');
      }
      const idb_key = this.doDelete(info);
      if (idb_key) {
        res.idb_key = idb_key;
      }
    } catch (e) {}
    return res;
  }
}

export default TdClient;
