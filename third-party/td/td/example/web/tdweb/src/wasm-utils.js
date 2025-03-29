// 1. +++ fetchAndInstantiate() +++ //

// This library function fetches the wasm module at 'url', instantiates it with
// the given 'importObject', and returns the instantiated object instance

export async function instantiateStreaming(url, importObject) {
  let result = await WebAssembly.instantiateStreaming(fetch(url), importObject);
  return result.instance;
}
export function fetchAndInstantiate(url, importObject) {
  return fetch(url)
    .then(response => response.arrayBuffer())
    .then(bytes => WebAssembly.instantiate(bytes, importObject))
    .then(results => results.instance);
}

// 2. +++ instantiateCachedURL() +++ //

// This library function fetches the wasm Module at 'url', instantiates it with
// the given 'importObject', and returns a Promise resolving to the finished
// wasm Instance. Additionally, the function attempts to cache the compiled wasm
// Module in IndexedDB using 'url' as the key. The entire site's wasm cache (not
// just the given URL) is versioned by dbVersion and any change in dbVersion on
// any call to instantiateCachedURL() will conservatively clear out the entire
// cache to avoid stale modules.
export function instantiateCachedURL(dbVersion, url, importObject) {
  const dbName = 'wasm-cache';
  const storeName = 'wasm-cache';

  // This helper function Promise-ifies the operation of opening an IndexedDB
  // database and clearing out the cache when the version changes.
  function openDatabase() {
    return new Promise((resolve, reject) => {
      var request = indexedDB.open(dbName, dbVersion);
      request.onerror = reject.bind(null, 'Error opening wasm cache database');
      request.onsuccess = () => {
        resolve(request.result);
      };
      request.onupgradeneeded = event => {
        var db = request.result;
        if (db.objectStoreNames.contains(storeName)) {
          console.log(`Clearing out version ${event.oldVersion} wasm cache`);
          db.deleteObjectStore(storeName);
        }
        console.log(`Creating version ${event.newVersion} wasm cache`);
        db.createObjectStore(storeName);
      };
    });
  }

  // This helper function Promise-ifies the operation of looking up 'url' in the
  // given IDBDatabase.
  function lookupInDatabase(db) {
    return new Promise((resolve, reject) => {
      var store = db.transaction([storeName]).objectStore(storeName);
      var request = store.get(url);
      request.onerror = reject.bind(null, `Error getting wasm module ${url}`);
      request.onsuccess = event => {
        if (request.result) resolve(request.result);
        else reject(`Module ${url} was not found in wasm cache`);
      };
    });
  }

  // This helper function fires off an async operation to store the given wasm
  // Module in the given IDBDatabase.
  function storeInDatabase(db, module) {
    var store = db.transaction([storeName], 'readwrite').objectStore(storeName);
    var request = store.put(module, url);
    request.onerror = err => {
      console.log(`Failed to store in wasm cache: ${err}`);
    };
    request.onsuccess = err => {
      console.log(`Successfully stored ${url} in wasm cache`);
    };
  }

  // This helper function fetches 'url', compiles it into a Module,
  // instantiates the Module with the given import object.
  function fetchAndInstantiate() {
    return fetch(url)
      .then(response => response.arrayBuffer())
      .then(buffer => WebAssembly.instantiate(buffer, importObject));
  }

  // With all the Promise helper functions defined, we can now express the core
  // logic of an IndexedDB cache lookup. We start by trying to open a database.
  return openDatabase().then(
    db => {
      // Now see if we already have a compiled Module with key 'url' in 'db':
      return lookupInDatabase(db).then(
        module => {
          // We do! Instantiate it with the given import object.
          console.log(`Found ${url} in wasm cache`);
          return WebAssembly.instantiate(module, importObject);
        },
        errMsg => {
          // Nope! Compile from scratch and then store the compiled Module in 'db'
          // with key 'url' for next time.
          console.log(errMsg);
          return fetchAndInstantiate().then(results => {
            try {
              storeInDatabase(db, results.module);
            } catch (e) {
              console.log('Failed to store module into db');
            }
            return results.instance;
          });
        }
      );
    },
    errMsg => {
      // If opening the database failed (due to permissions or quota), fall back
      // to simply fetching and compiling the module and don't try to store the
      // results.
      console.log(errMsg);
      return fetchAndInstantiate().then(results => results.instance);
    }
  );
}

export async function instantiateAny(version, url, importObject) {
  console.log("instantiate");
  try {
    return await instantiateStreaming(url, importObject);
  } catch (e) {
    console.log("instantiateStreaming failed", e);
  }
  try {
    return await instantiateCachedURL(version, url, importObject);
  } catch (e) {
    console.log("instantiateCachedURL failed", e);
  }
  throw new Error("can't instantiate wasm");
}

