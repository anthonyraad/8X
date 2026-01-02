'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "3e62245ce8c1687e2d1f0a3ad1cc59d7",
"assets/AssetManifest.bin.json": "e6b1df2d0cb27ec929191519bda76883",
"assets/AssetManifest.json": "e89f6111e61b9df9ac3a20d9b30a5e01",
"assets/assets/fonts/balatro.ttf": "ae77b487f2d77ffca107f622efcd8462",
"assets/assets/fonts/DSEG7Classic-Regular.ttf": "74679fa2f59e3e884f6f570c2f71115e",
"assets/assets/images/+11mod.png": "293f7addbfed3588fc8d4336ae47fee0",
"assets/assets/images/+1mod.png": "c24db437a2361d03528b61b014a17e76",
"assets/assets/images/+3mod.png": "1e7268c2a78197535d288c81fb71bfb2",
"assets/assets/images/-1mod.png": "a67efe075f58b3991e8a2d3c64c333a4",
"assets/assets/images/-3mod.png": "7e4506a011cdc04628065b793eba5820",
"assets/assets/images/-halfmod.png": "f2e3247c4a17e6e0050c39394212e829",
"assets/assets/images/10.png": "75ca0cc4f8af3a1a163a2ad6b7210055",
"assets/assets/images/2.png": "cbc6d5ca6b9b2152cc13abd461284a1b",
"assets/assets/images/2xmod.png": "2d14255ac67476b64f9a9b9070914578",
"assets/assets/images/3.png": "1376b676e46a58783854e2483196b724",
"assets/assets/images/4.png": "3e5b9e4ccb43192790e2636d68f6a77f",
"assets/assets/images/5.png": "d49e30b1f2c57ac457df6d87405bb406",
"assets/assets/images/6.png": "a97a73362611ad90d087844fbca14baa",
"assets/assets/images/7.png": "d46c06b49fda1beba9b2269b1764ae43",
"assets/assets/images/8.png": "708d6ab614949c1d57d12d19394ca44a",
"assets/assets/images/9.png": "ce27a2bc427851e67e7966761fe755ea",
"assets/assets/images/a.png": "7be5414ac03b37cd7f99fe2bc22027ab",
"assets/assets/images/cardback.png": "01b5c58a437741bea104a27cb04e679c",
"assets/assets/images/cardback2.png": "ffc777cff15710b4dff4f530975dcd02",
"assets/assets/images/draw1mod.png": "49cd9ac8802776fce10c748eb406a78e",
"assets/assets/images/j.png": "dea978c39182e88a6066b973047882f6",
"assets/assets/images/jkr.png": "a4f35ffd3037acc501ce985a120b3817",
"assets/assets/images/k.png": "fb35ac3674856c83b060895b0565b626",
"assets/assets/images/mulliganmod.png": "9aeea428f14b32932134ae500dc29809",
"assets/assets/images/playmat1.png": "4ad1b9924f04fdfde9a4f1725dcf8b3f",
"assets/assets/images/playmat2.png": "65bd17d1e020b309a1445adaefa71790",
"assets/assets/images/playmat3.png": "b47ce656dc910c7375436d8958f3f6ae",
"assets/assets/images/playmat4.png": "6551f4807acf05cfcbb0e1e1403c550a",
"assets/assets/images/playmat5.png": "637107590b0a929e08ff769114913154",
"assets/assets/images/q.png": "bd957bbbe813c4c91e644505b81793dc",
"assets/assets/images/rewindmod.png": "82870bf006193d3fea7515464bd0fb16",
"assets/assets/sounds/cardplay.mp3": "672b7dd56dfc7af412e50c442181e0d0",
"assets/assets/sounds/gameloss.mp3": "09677cf95ba80a84908d142c95aa36f9",
"assets/assets/sounds/gamewin.mp3": "1f8eb919c6bf6e4ef760573f445549b8",
"assets/assets/sounds/modplay.mp3": "0b9419dd8e0ee9de86fc7d6df8153b8e",
"assets/assets/sounds/oppwinplay.mp3": "a74e38298de53e55d1c001b86d87ed0a",
"assets/assets/sounds/tap.mp3": "daeed2c94a404be341f827214ca2ace6",
"assets/assets/sounds/winplay.mp3": "7d6820953159bed654e3c08f97137801",
"assets/FontManifest.json": "50c0b7b8e3b29472e6eb786a39c80791",
"assets/fonts/MaterialIcons-Regular.otf": "2c8e8d89daa0b828eac4ea499f9d1ccd",
"assets/NOTICES": "2cf3585246c29ef126689bcca54d4857",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "140ccb7d34d0a55065fbd422b843add6",
"canvaskit/canvaskit.js.symbols": "58832fbed59e00d2190aa295c4d70360",
"canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"canvaskit/chromium/canvaskit.js": "5e27aae346eee469027c80af0751d53d",
"canvaskit/chromium/canvaskit.js.symbols": "193deaca1a1424049326d4a91ad1d88d",
"canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"canvaskit/skwasm.js": "1ef3ea3a0fec4569e5d531da25f34095",
"canvaskit/skwasm.js.symbols": "0088242d10d7e7d6d2649d1fe1bda7c1",
"canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"canvaskit/skwasm_heavy.js": "413f5b2b2d9345f37de148e2544f584f",
"canvaskit/skwasm_heavy.js.symbols": "3c01ec03b5de6d62c34e17014d1decd3",
"canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "888483df48293866f9f41d3d9274a779",
"flutter_bootstrap.js": "1235bed0008d33a00cf34d8f2bbd2314",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "a18008fd4795459245a36b359bb53a9b",
"/": "a18008fd4795459245a36b359bb53a9b",
"main.dart.js": "79f76ceef92f0805ed21873499d0ed0f",
"manifest.json": "3ae41f96740ec807472855ae7103eb26",
"version.json": "ab6abb70df15b1383ec5c3632bd273e7"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
