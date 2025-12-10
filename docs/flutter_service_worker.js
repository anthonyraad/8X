'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "42e525f687b59ae30284820c6050c1c8",
"assets/AssetManifest.bin.json": "6a654d0c03e82043616add36896c03d7",
"assets/AssetManifest.json": "29c8eec68d18fda3de0efcc5c34e9971",
"assets/assets/fonts/DSEG7Classic-Regular.ttf": "74679fa2f59e3e884f6f570c2f71115e",
"assets/assets/images/+11mod.png": "293f7addbfed3588fc8d4336ae47fee0",
"assets/assets/images/+1mod.png": "c24db437a2361d03528b61b014a17e76",
"assets/assets/images/+3mod.png": "1e7268c2a78197535d288c81fb71bfb2",
"assets/assets/images/-1mod.png": "a67efe075f58b3991e8a2d3c64c333a4",
"assets/assets/images/-3mod.png": "7e4506a011cdc04628065b793eba5820",
"assets/assets/images/-halfmod.png": "f2e3247c4a17e6e0050c39394212e829",
"assets/assets/images/10.png": "e8bd846d38e12839c00d3e85e5da4476",
"assets/assets/images/2.png": "18c394c43d4b0a706c47481c3cb852c3",
"assets/assets/images/2xmod.png": "2d14255ac67476b64f9a9b9070914578",
"assets/assets/images/3.png": "75d61e20a63a4dedb7616eae534f2f14",
"assets/assets/images/4.png": "04934ef3a59f73a66e6d35f1ce0e6c7c",
"assets/assets/images/5.png": "112f20fc60e908f81880d6a1c91b6206",
"assets/assets/images/6.png": "c07527cb14294dfb840f35d3df6f8258",
"assets/assets/images/7.png": "102dedea1989d5f6924eba98f8a36407",
"assets/assets/images/8.png": "744b3b9ac0018722ba603ec7916821bf",
"assets/assets/images/9.png": "b8bb5c84eaaa122afaecf038ef397007",
"assets/assets/images/a.png": "7593f320d86f64ac1a240782966b7b5d",
"assets/assets/images/cardback.png": "d1905ceccbf4d308c573e05ecc3142de",
"assets/assets/images/draw1mod.png": "49cd9ac8802776fce10c748eb406a78e",
"assets/assets/images/j.png": "04facc629851e23c032c154308383a73",
"assets/assets/images/jkr.png": "9f9f87b921a66d2ea269821b1a5d596f",
"assets/assets/images/k.png": "753bc90e00078cd25a8f76dc0c3ac3aa",
"assets/assets/images/mulliganmod.png": "9aeea428f14b32932134ae500dc29809",
"assets/assets/images/playmat.png": "1a5d0fc853e2a19f6dded27029b8fa06",
"assets/assets/images/playmat1.png": "80db75e505c4d47aaec83d7758c71afa",
"assets/assets/images/playmat2.png": "71402577dcb553247098e6bef9a842e7",
"assets/assets/images/playmat3.png": "7b4deaec38a31d4d3c1f2ca072f8ae89",
"assets/assets/images/q.png": "4743e55cef41e9ce5cb7b70a06fe6d8f",
"assets/assets/images/rewindmod.png": "82870bf006193d3fea7515464bd0fb16",
"assets/assets/sounds/cardplay.mp3": "d3b400fcaa1123b12da0896dbbe658df",
"assets/assets/sounds/gameloss.mp3": "8d75fd637cdc91462597a10d3a7f7c72",
"assets/assets/sounds/gamewin.mp3": "e6527726b547b00d74eedc227e408f75",
"assets/assets/sounds/modplay.mp3": "c314add052f44601b61f39fb751a78b7",
"assets/assets/sounds/tap.mp3": "058761185556b7953b1c81afafdf79bd",
"assets/assets/sounds/winplay.mp3": "f69249d8e16d585b02fe5c27f2ef0662",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/fonts/MaterialIcons-Regular.otf": "3084cb161ae8e2be4dbf274ef180c9d0",
"assets/NOTICES": "49686179e0f942df29db52cd388e9355",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "9bb2aaa0f9a9213b623947fa682efa76",
"canvaskit/canvaskit.js": "1b6f288ce484225c079db75751f22814",
"canvaskit/canvaskit.js.symbols": "a3b4c42fca4cdf168ac2718d2d09bc7a",
"canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"canvaskit/chromium/canvaskit.js": "0d3e893c15ead7da6d36efe877694617",
"canvaskit/chromium/canvaskit.js.symbols": "03d31667dc4f5676bafee152fe8ff4d7",
"canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"canvaskit/skwasm.js": "66504b1416ee7a68aee25f965a90949c",
"canvaskit/skwasm.js.symbols": "09f5d843a50cf276b2dba6fc466b98e6",
"canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"canvaskit/skwasm_heavy.js": "31e5a202dc9ca33e695bc30bca93566c",
"canvaskit/skwasm_heavy.js.symbols": "7f3cadcdd3b8e95e0160e83d82085ef6",
"canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "3265c4a743599232db370a9249855db3",
"flutter_bootstrap.js": "f6999d7233af6d67e6ec7b0da61e7630",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "4d72fb60cfe5cec333155a26fa521b51",
"/": "4d72fb60cfe5cec333155a26fa521b51",
"main.dart.js": "76de29a61528f52aa6244130448a5757",
"manifest.json": "3ae41f96740ec807472855ae7103eb26",
"version.json": "e9320b6cf641855b338da7e466d2c66d"};
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
