'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "de065ac22627898fc3b0d1382d5deca2",
"assets/AssetManifest.bin.json": "e723c3ae1747c30ce4a8b05c270346bd",
"assets/AssetManifest.json": "dc2a6ff49ad709fd88cf58007815243e",
"assets/assets/applogo.jpg": "2e94775337b76c86ce1e0f9be0f894ae",
"assets/assets/background.jpg": "de4a32535578e611355ce4785f9657cf",
"assets/assets/buffalo_.jpg": "0f21746395163610782b4c3f7a63471a",
"assets/assets/Chloritronn.png": "63cf58bcf21ab3c4e1479daf44702b6d",
"assets/assets/cow.jpg": "2855c4322af63bf7646cb1221d4b5bd8",
"assets/assets/fonts/DMSerifText-Italic.ttf": "48d9b180aa132af0fe0d8ad1d5f8184d",
"assets/assets/fonts/DMSerifText-Regular.ttf": "26a61f86766bef242af31d725837a52a",
"assets/assets/fonts/OpenSans-Italic-VariableFont_wdth,wght.ttf": "31d95e96058490552ea28f732456d002",
"assets/assets/fonts/OpenSans-VariableFont_wdth,wght.ttf": "78609089d3dad36318ae0190321e6f3e",
"assets/assets/login.png": "a40869c6e3817c633af08c604dd31f86",
"assets/assets/signup3.png": "ef4aa80af14539ea5a9abdc416f391ff",
"assets/assets/soil.jpg": "72ee5870b77de1c5fba3641e06807e1b",
"assets/assets/sun.jpg": "256e2b3d469326c72195f71c9077354e",
"assets/assets/tree.jpg": "474a61bd17c3381840a5684d707486f3",
"assets/assets/water_quality.jpg": "b4bf7dfbb24eb7e8caa713f0090c9267",
"assets/assets/weather.png": "14aab14d4fe80ab2673eaca1d1fd47aa",
"assets/FontManifest.json": "179513f8cdcc671da1d499dcbaaf2491",
"assets/fonts/MaterialIcons-Regular.otf": "30103010b4ef8b2d6dfec17be21ed853",
"assets/NOTICES": "913b806027c5f0fd619541c1012421c6",
"assets/packages/amplify_authenticator/assets/social-buttons/google.png": "a1e1d65465c69a65f8d01226ff5237ec",
"assets/packages/amplify_authenticator/assets/social-buttons/SocialIcons.ttf": "1566e823935d5fe33901f5a074480a20",
"assets/packages/amplify_auth_cognito_dart/lib/src/workers/workers.min.js": "ba1640c479f80566a30f0699f3524ca1",
"assets/packages/amplify_auth_cognito_dart/lib/src/workers/workers.min.js.map": "9db73d612f24f17196def9fb76eb7f4f",
"assets/packages/amplify_secure_storage_dart/lib/src/worker/workers.min.js": "9a2b99dd0e5f96670060b4887b9e8c30",
"assets/packages/amplify_secure_storage_dart/lib/src/worker/workers.min.js.map": "ce043277a9386bc85a1141db8c0cfd46",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/packages/fluttertoast/assets/toastify.css": "a85675050054f179444bc5ad70ffc635",
"assets/packages/fluttertoast/assets/toastify.js": "56e2c9cedd97f10e7e5f1cebd85d53e3",
"assets/packages/flutter_map/lib/assets/flutter_map_logo.png": "208d63cc917af9713fc9572bd5c09362",
"assets/packages/syncfusion_flutter_charts/assets/fonts/Roboto-Medium.ttf": "58aef543c97bbaf6a9896e8484456d98",
"assets/packages/syncfusion_flutter_charts/assets/fonts/Times-New-Roman.ttf": "e2f6bf4ef7c6443cbb0ae33f1c1a9ccc",
"assets/packages/wakelock_plus/assets/no_sleep.js": "7748a45cd593f33280669b29c2c8919a",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "728b2d477d9b8c14593d4f9b82b484f3",
"canvaskit/canvaskit.js.symbols": "bdcd3835edf8586b6d6edfce8749fb77",
"canvaskit/canvaskit.wasm": "7a3f4ae7d65fc1de6a6e7ddd3224bc93",
"canvaskit/chromium/canvaskit.js": "8191e843020c832c9cf8852a4b909d4c",
"canvaskit/chromium/canvaskit.js.symbols": "b61b5f4673c9698029fa0a746a9ad581",
"canvaskit/chromium/canvaskit.wasm": "f504de372e31c8031018a9ec0a9ef5f0",
"canvaskit/skwasm.js": "ea559890a088fe28b4ddf70e17e60052",
"canvaskit/skwasm.js.symbols": "e72c79950c8a8483d826a7f0560573a1",
"canvaskit/skwasm.wasm": "39dd80367a4e71582d234948adc521c0",
"favicon.png": "352a05256273593e3e2b5d173d54cf60",
"firebase-messaging-sw.js": "90c1c248d7b25ebdbfd3829541f8e6f7",
"flutter.js": "83d881c1dbb6d6bcd6b42e274605b69c",
"flutter_bootstrap.js": "4f2689ca619731ad716302f7d8965adc",
"icons/Icon-192.png": "90a948ad88bf1c17a5a40ed40bf4905a",
"icons/Icon-512.png": "76feaf63bcbf28ae35c368fa70d14ce7",
"icons/Icon-maskable-192.png": "90a948ad88bf1c17a5a40ed40bf4905a",
"icons/Icon-maskable-512.png": "76feaf63bcbf28ae35c368fa70d14ce7",
"index.html": "371d9517d7e709cf7764c7ac8accd74d",
"/": "371d9517d7e709cf7764c7ac8accd74d",
"main.dart.js": "d4e7d9ebc02d47e0b7911a88f1b4cdf2",
"manifest.json": "7d5f81ca60762fbfaf6e03d1908e56cf",
"maskable": "d41d8cd98f00b204e9800998ecf8427e",
"mobile-app.png": "c2b1747bda9c67c734ff806e5bf0e684",
"smartphone.png": "07c28484887d1e8f958e7975763a2d2b",
"version.json": "452b6a0bcd57f5a3ccfc35e85bb3a0d5"};
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
