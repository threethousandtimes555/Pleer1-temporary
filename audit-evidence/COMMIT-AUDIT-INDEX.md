# Pleer1 commit-by-commit audit index

- Repository: `threethousandtimes555/Pleer1-Lab`
- Branch: `feature/youtubei-js-ios-fallback-2026-11-19`
- Inventory snapshot: 20 November 2026
- Commits in branch history returned by GitHub API: **298** (pages: 100 + 100 + 98).
- Every commit SHA below has been individually requested through the GitHub commit endpoint for its metadata and diff. The full semantic reconciliation against current HEAD is **in progress**; this index is not a claim that all 298 changes have already been exhaustively interpreted or device-verified.
- Dates are Git author timestamps in UTC. Full SHA is retained for traceability.

## Complete commit inventory

| # | Date (UTC) | Commit | Subject |
|---:|---|---|---|
| 1 | 2026-11-20T08:26:35Z | `a69ddc5a7421a5346ed6a5009f749c2186a5d956` | Store compact metadata-only listening history |
| 2 | 2026-11-20T08:26:32Z | `84e60f2ee4a041c585e2ce2e027f998cf6ccd67a` | Add compact metadata-only history entry model |
| 3 | 2026-11-20T07:42:44Z | `b414fbbd8495a506a5281937bff8ef48d7523068` | Instrument repeat-one mode and natural completion |
| 4 | 2026-11-20T07:41:17Z | `2da04a48c853341b93f9d600da0fc386a4a78899` | Cap and normalize recent listening history |
| 5 | 2026-11-19T20:33:06Z | `6fb237617105086aa99668cd37621da00a94b294` | build: add ZIP-named inspection copy of unsigned IPA |
| 6 | 2026-11-19T20:16:11Z | `4edd6da89053a074ea3b1ff82f035022add1bc25` | Fix Swift interpolation in catalog diagnostics |
| 7 | 2026-11-19T19:41:27Z | `29cc97997a243cda5796605e64a290987eecaf3a` | Cancel catalog deadline timer after early completion |
| 8 | 2026-11-19T19:40:48Z | `47c4842192a7271b6c78bf8959724ef9b39d7846` | Log end-to-end YouTube Music catalog deadline |
| 9 | 2026-11-19T19:40:38Z | `54d6af0ef93ef413dfe724e973315e62df2ea400` | Bound complete YTM catalog search to 15 seconds |
| 10 | 2026-11-19T19:38:41Z | `f8965a957de51b0c23c50926d4298770e489a109` | Trigger source validation on active integration branch |
| 11 | 2026-11-19T19:38:31Z | `98a124957024ccf9d87bb51a27c2842427e52745` | Add Linux source syntax validation workflow |
| 12 | 2026-11-19T19:37:52Z | `829a26db66ec285977f43478b9dbba93cf29e514` | Prepare youtubei runtime in manual GitHub IPA build |
| 13 | 2026-11-19T19:37:44Z | `f5e025cf64f9e899db280a2fb510e2f053c548ba` | Enable simulator smoke tests for YTM integration branch |
| 14 | 2026-11-19T19:28:43Z | `79f9f7d42df55d3170ed4a4681016d3cd69f18f7` | Clarify YouTube Music suggestion fallback conditions |
| 15 | 2026-11-19T19:27:25Z | `ad8bd6f4bad7dd4d31a206672aee5ddd5cfcad60` | Correct Swift key-path syntax in ranking test |
| 16 | 2026-11-19T19:27:16Z | `a3ab6e6a46921b204353ed58bc109b6065fb2399` | Add ranking coverage for YouTube Music result kinds |
| 17 | 2026-11-19T19:26:10Z | `50699d52b1d31034ea173dac789c7fa89461adc0` | Correct Swift interpolation in search diagnostics |
| 18 | 2026-11-19T19:25:48Z | `c8bb770736c1c34c10112059f2acca9930a77ef0` | Bound YTM catalog wait and retry spelling when Music shelves are empty |
| 19 | 2026-11-19T19:25:45Z | `73863bb021458d6a5ba793ae4e4a9410e6ac2b9c` | Process legacy search results before YTM catalog merge |
| 20 | 2026-11-19T19:09:52Z | `6f53515f8974a609f0f976377a024dddc5d15d4f` | Validate YouTube video IDs again at the Swift boundary |
| 21 | 2026-11-19T19:09:48Z | `2f402de9fa9fbc2312f8baeb1d4a9ed83e59ced7` | Avoid serializing unknown artist objects as display text |
| 22 | 2026-11-19T19:08:41Z | `38b833af4820ef7f19139c3f9a8e32f521b18868` | Map typed Sendable YouTube catalog items into Pleer tracks |
| 23 | 2026-11-19T19:08:35Z | `9c25c52878801456a6fb3dbf50c5fd336dcbb677` | Use a Sendable catalog result model across Swift concurrency |
| 24 | 2026-11-19T19:08:04Z | `a3b95983a941cf5b76c0f44436aa2d572ba60915` | Retry catalog search once after WebKit process termination |
| 25 | 2026-11-19T19:06:12Z | `261fe7a5d7feb32ddb5efbf51342e1640adbf84c` | Allow one youtubei.js session retry within catalog search timeout |
| 26 | 2026-11-19T19:06:06Z | `94df65f4fd4743c3d3c0e0f3f7b648fcda2986de` | Start YouTube Music and legacy search sources together |
| 27 | 2026-11-19T19:05:59Z | `b7a18aea0b833727cd9c44e7a0db50fdd69e93ff` | Run YouTube Music and ordinary YouTube catalog queries concurrently |
| 28 | 2026-11-19T19:05:41Z | `80f5e827bdcef987ee95d926125c2fb32c8ab785` | Fix suggestion normalization and older WebKit thumbnail compatibility |
| 29 | 2026-11-19T19:05:27Z | `faefccc78884d5b5d74cec2b1b18232eced521de` | Add YouTube Music spelling suggestion fallback for empty catalog searches |
| 30 | 2026-11-19T19:04:58Z | `09c1a3c665d95326e5c3ac7ba87828ad3a89636c` | Parse YouTube Music result shelves using Musike's production response shape |
| 31 | 2026-11-19T18:56:51Z | `7223e30b24ca10acc1e93954a7ac9795732ad486` | Close cancellation race in YouTube catalog requests |
| 32 | 2026-11-19T18:55:59Z | `e6a0dd2691c876c4b0fca9eb07003f8df4b0b14b` | Cancel stale YouTube catalog search tasks cleanly |
| 33 | 2026-11-19T18:55:51Z | `c2fe19a420020f4c1993fa5c3ab9c2ce2efd16e6` | Clarify YouTube catalog completion handling |
| 34 | 2026-11-19T18:55:36Z | `16fc083c3833a4c5fc7fcfb52793bc2e94dfff04` | Clarify YouTube catalog source diagnostics and naming |
| 35 | 2026-11-19T18:55:29Z | `a570ec115bb6dc913136a4562d4d1136cbee5f14` | Rename Swift bridge to YouTube catalog search |
| 36 | 2026-11-19T18:55:26Z | `ed38acfe79a44cb0211380778bf9da1fbe06936c` | Name the combined YouTube Music + YouTube catalog bridge explicitly |
| 37 | 2026-11-19T18:55:04Z | `5857524aaa0a0b98bc54fe39e879ce633b7b17a0` | Parse modern ordinary YouTube video results with youtubei.js |
| 38 | 2026-11-19T18:54:45Z | `f1b45c1c6f0894e2d5fa7d6651da30d995c51d06` | Keep YouTube Music video search available if song search fails |
| 39 | 2026-11-19T18:54:42Z | `b82f002029420376f74295130541b13e1d54d0fe` | Correct YouTube Music video URL interpolation |
| 40 | 2026-11-19T18:53:57Z | `a3827fc2d74e2911794a938afb25c707edb988a6` | Cancel pending YouTube Music searches when WebKit process terminates |
| 41 | 2026-11-19T18:53:51Z | `b7a1a2025aed3ad9c22e990954a7b26fdf1e9196` | Harden YouTube Music shelf parsing for youtubei ObservedArray values |
| 42 | 2026-11-19T18:53:48Z | `edf0470081f2f8f268f8faea1a4fa120f9ea6d05` | Fix music result URL interpolation and search diagnostics |
| 43 | 2026-11-19T18:53:24Z | `edecb21249bafa851c58a5f7e30a3e6c573d8bfb` | Make YouTube Music the primary Pleer1 search catalog |
| 44 | 2026-11-19T18:53:05Z | `e772cee119eb7e8a1037385048a68a747314190d` | Prioritize YouTube Music songs and music videos in search ranking |
| 45 | 2026-11-19T18:53:03Z | `a79b64ea8683e9fd7ae0ed57374eccda2474eda4` | Add explicit YouTube catalog result kind to Track |
| 46 | 2026-11-19T18:52:57Z | `3b4427eff93873346696c67ec3999ee8a5506a43` | Bridge YouTube Music search through native WKWebView resolver |
| 47 | 2026-11-19T18:52:50Z | `894573b571bd06d5c9dbbf5f68e556c1454f547a` | Add YouTube Music catalog search to embedded youtubei bridge |
| 48 | 2026-11-19T18:09:01Z | `1c47717c3f264cb5fab63ec1dc40389f0eb24d9b` | refactor: make stale seek token diagnostics explicit |
| 49 | 2026-11-19T18:07:08Z | `86f02970a9b17fb52b04cfd5c73e9277a0bb6289` | ui: center cellular confirmation text to match approved reference |
| 50 | 2026-11-19T18:06:49Z | `9313815b56db44540558d50e3297cd956509abc6` | fix: use consistent Любимое naming and keep downloaded-only tracks out of favorites |
| 51 | 2026-11-19T18:06:25Z | `e9f9a39a03756566ebc6a0c7730c2f3341f22d26` | fix: snapshot lock-screen seek identity before actor handoff |
| 52 | 2026-11-19T18:06:22Z | `fd6d5d01383ec3180c9d99c3ad6ea4ae15740bc8` | fix: render thumbnail samples into valid pixel buffer |
| 53 | 2026-11-19T18:05:43Z | `3f088b0a9c3f843f238250b9529039a690e95c64` | fix: restore inline favorites and align cellular prompt with approved layout |
| 54 | 2026-11-19T18:05:41Z | `de0f65c91c6f6de124c62e0d5c2af51832401686` | fix: reject stale seeks across track changes and log seek source |
| 55 | 2026-11-19T18:05:38Z | `a623bce5fa4da85230bec71af03cf60d50ddabf0` | fix: deduplicate combined library by stable track ID |
| 56 | 2026-11-19T18:05:34Z | `4793520e833c416216929e99c805384a1f94dcdb` | fix: detect square artwork embedded in YouTube thumbnails |
| 57 | 2026-11-19T14:28:33Z | `1cd73522a57d4ba7b0626b3766e30f01c1171bfe` | Reset YouTube end watchdog baseline after manual seek |
| 58 | 2026-11-19T14:23:05Z | `96b54c5e7de9ae8d748b1d9ad4e3dbf5f67f5bbf` | revert unrelated pre-build changes; restore prior behavior |
| 59 | 2026-11-19T14:23:02Z | `5ec6207cceccb0c805916a4eaf01664db1860194` | revert unrelated pre-build changes; restore prior behavior |
| 60 | 2026-11-19T14:22:59Z | `dd9f7ca09b8f4ca851aac8e2bfbfe36c4bee3480` | revert unrelated pre-build changes; restore prior behavior |
| 61 | 2026-11-19T14:19:46Z | `1bef38f881c9dc00aeee14c7ef36a348d03b6518` | library: deduplicate local files in combined play queue |
| 62 | 2026-11-19T14:19:30Z | `6dc1ee61d7307e78adffc709dd8eae63624515a3` | library: keep offline downloads out of Favorites |
| 63 | 2026-11-19T14:18:43Z | `91cbefef1e80d61518a1f637abb72cdde393de7a` | diagnostics: distinguish manual seek from natural completion |
| 64 | 2026-11-19T13:19:14Z | `cb6487a3ca0fac49816bdb41d6365a261bbd6502` | diagnostics: record app lifecycle transitions |
| 65 | 2026-11-19T13:19:11Z | `58edd69eef31b0f339afcc9621c0f9b817ec4dcd` | ui: remove duplicate favorite menu action |
| 66 | 2026-11-19T13:19:08Z | `e9df32cbfd3b93f6b58e6cc8730d7d997735713e` | library: favorite every imported audio file |
| 67 | 2026-11-19T13:06:48Z | `ee4ee8e2a727d6ad6fe89eb0b3f771710c2ebb7a` | artwork: keep square crop outside YouTube |
| 68 | 2026-11-19T13:06:25Z | `2dc13d7dcd0ac2bf82cd704a725764f2d9db1671` | artwork: preserve YouTube thumbnail aspect ratio |
| 69 | 2026-11-19T13:02:51Z | `ea2bdd28866f3d489c94102549cb777495644447` | artwork: render track covers as square crops |
| 70 | 2026-11-19T13:02:25Z | `4a16acc5171e3b192b9dc2be362f7f8e8d7bd481` | import: record external file handoff |
| 71 | 2026-11-19T13:02:23Z | `0aa139c0e89b223bcdb70d0fe212a0c9a0f12f13` | import: add diagnostics for multi-file handoff |
| 72 | 2026-11-19T13:02:20Z | `38bd4c252d2f433de57bd375ec34178a816bc7ff` | library: keep recent and unmarked local files out of favorites |
| 73 | 2026-11-19T12:46:02Z | `746fc614fa8db70cd05f977baa12debeac66c3c5` | library: include all local audio in Favorites |
| 74 | 2026-11-19T12:45:47Z | `94baed9b32536e924338030123b4a95e9b616ca4` | library: preserve cached tracks in Favorites without misleading remove action |
| 75 | 2026-11-19T12:45:43Z | `d68452958af70c174ac21a89752bcaca005cee2c` | library: persist Telegram imports in Favorites |
| 76 | 2026-11-19T12:45:19Z | `cc9bc0e552491213b5f66abca09e152d21be172c` | library: include offline downloads in Favorites |
| 77 | 2026-11-19T12:45:17Z | `c022c992e82c53fe55a8744ff1ba0ee737ef9ccb` | library: automatically favorite Telegram imports |
| 78 | 2026-11-19T12:36:39Z | `87c620a5e53a18d2bb848f31aa5abf3f9477cbc4` | ui: put library shortcuts first on My screen |
| 79 | 2026-11-19T12:36:00Z | `b8aafeec5b7f7880367ee07dc833f866486febe0` | ui: restore compact three-tab navigation and add nested library screens |
| 80 | 2026-11-19T12:23:50Z | `e065fbedeb38cf93514e78834fd99f2f41cb3e84` | ui: keep favorite download hint on downloads tab |
| 81 | 2026-11-19T12:23:28Z | `046356ad764d40d732ba6d7959a83e74167c0990` | ui: keep empty states compatible with iOS 16 |
| 82 | 2026-11-19T12:23:07Z | `68422d712a0ddc5b3a22f4c2371deddbf352b6ef` | ui: make favorites and downloads separate tabs |
| 83 | 2026-11-19T11:38:21Z | `7eabcbcbb83fe1aa402dc2831dbac29f8f507989` | fix: use existing cover view for player backdrop |
| 84 | 2026-11-19T11:38:19Z | `80c06a4e0a3413581b02f22e605183aa40330a78` | fix: correct storage capacity types and error return |
| 85 | 2026-11-19T11:27:54Z | `606eea203fd2e09fcaebb6b35b078ef7ef717e9c` | ui: move download hint to downloaded library |
| 86 | 2026-11-19T11:22:03Z | `7e1f8e38fbcc1445a68571d4bd288db332501a03` | ui: shorten favorite download hint |
| 87 | 2026-11-19T11:11:30Z | `bb32a4e12cc376c4b86b5b7623d6a1a56640d8dd` | fix: normalize expected MIME before signature matching |
| 88 | 2026-11-19T11:10:03Z | `08b07cfd54a94ec2e721d3de4e2377558b054f33` | fix: reconcile latest network path before marking download failed |
| 89 | 2026-11-19T11:08:53Z | `6a5fd56208488908075bb8ca049c15524a2efbc8` | fix: enforce cellular consent in download session configuration |
| 90 | 2026-11-19T11:08:01Z | `3b651b4d1b2d0bfcdaa0b95dfed1b68538055b00` | chore: log resolver invalidation before download resume |
| 91 | 2026-11-19T11:07:25Z | `f5344f023d267fd8eada419c1cd903b1a67b1c05` | fix: preserve active playback during resolver cache invalidation |
| 92 | 2026-11-19T11:06:20Z | `56031ebb69b358fd4439345917d605b3b83a9952` | fix: match downloaded audio signature to resolved format |
| 93 | 2026-11-19T11:05:39Z | `4195aae428718a2f4d7ed65aa35c5ac8abb33919` | fix: propagate cancellation from JS fallback resolver |
| 94 | 2026-11-19T11:05:21Z | `0f3ee45f0807aceba51a66caeeae9319e150200a` | fix: cancel pending JS resolver continuations on route changes |
| 95 | 2026-11-19T11:05:00Z | `da9bd55dd8bedda51d39f99866d33e52717a6007` | fix: stop resolver client fallback when task is cancelled |
| 96 | 2026-11-19T11:03:25Z | `3a740101007f1ed535a2a83a74e95de43d58cba7` | fix: cancel invalidated resolver network tasks |
| 97 | 2026-11-19T11:02:48Z | `be3bfb209525e4c06d7969091446a324e0916ad9` | fix: await both resolver cache invalidations before resuming downloads |
| 98 | 2026-11-19T11:02:19Z | `e00b1ae74adb82b2d21ceda8a078b1bc0b947f30` | fix: reject stale shared resolver results after invalidation |
| 99 | 2026-11-19T11:02:09Z | `b646fcdf5b5543b5de4c9170f0f24aa3c384dfc8` | fix: await JS resolver invalidation by video ID |
| 100 | 2026-11-19T11:01:48Z | `220a3615d4b78d10766d13339c1b3223cb02d6f7` | fix: invalidate JS resolver jobs after network handoff |
| 101 | 2026-11-19T11:01:30Z | `94468be2dd716ce3839d71e14641add89f75820c` | fix: invalidate in-flight resolver jobs on network handoff |
| 102 | 2026-11-19T10:58:31Z | `e86264b834e8bae6395e85f4d859fb75b07a2da3` | fix: distinguish low storage from track size limit |
| 103 | 2026-11-19T10:57:25Z | `126c382043d804dc4d4efd477b793ec7c547b2b4` | fix: refresh IP-bound stream after network handoff |
| 104 | 2026-11-19T10:56:02Z | `4671f4df30470b57daa05102ad217ecd0555a375` | chore: log effective offline download size limit |
| 105 | 2026-11-19T10:55:29Z | `98b65af16447efa773559cc6e26d69984abbb93c` | fix: cap unknown-size downloads to available storage |
| 106 | 2026-11-19T10:54:06Z | `5d5aa218c9df6bd5b49c5bd8ef98edabeb2587b8` | fix: close cancellation race in capped download task |
| 107 | 2026-11-19T10:53:30Z | `6a60eba5c42b2132c03cd26449b6730accc1779b` | fix: retain refreshed stream across network handoff |
| 108 | 2026-11-19T10:52:10Z | `e40a0e53fa005b6cb6ab49086a65174114f0c655` | ui: add subtle offline download hint and defer active file removal |
| 109 | 2026-11-19T10:52:00Z | `0045b72b32cf2968816bebcabcd017ec9b058c96` | fix: finish deferred audio deletion after track switch |
| 110 | 2026-11-19T10:51:50Z | `c60abf47ed9133b339ab4c2909ee335a72706ce9` | fix: persist deferred offline file deletion |
| 111 | 2026-11-19T10:51:02Z | `90a85a5f116cbedf82f0b5057d60c0c617621cbe` | fix: harden offline downloads and network handoffs |
| 112 | 2026-11-19T09:48:56Z | `325b7e19ccf3b273812f0b2e0ef39f58061c92d9` | fix: refresh cellular prompt after queue removals |
| 113 | 2026-11-19T09:48:19Z | `4ab7a7ec0fff38bcff30e3dfc98683cf4d285ba7` | fix: estimate offline track storage before downloading |
| 114 | 2026-11-19T09:46:24Z | `d4891d73bc4e68ddd2525af6ec8238284e1e885b` | fix: invalidate cached stream before playback retry |
| 115 | 2026-11-19T09:46:18Z | `12ef6399777dfa1987d079b290b33559c0812ee3` | fix: invalidate resolver cache before offline stream retry |
| 116 | 2026-11-19T09:46:11Z | `b83253b102c601e0122f64f3ea7ba6dfa8c4c307` | fix: cache resolved YouTube streams with expiry and invalidation |
| 117 | 2026-11-19T09:45:27Z | `f3b2e2ebe3aa3052817aa8a630d7c36d253e24d7` | fix: clean cancelled downloads and reject unsupported formats early |
| 118 | 2026-11-19T09:45:15Z | `2a6250cfb8da9291892e47c9bbf910fb23c1a8e8` | fix: retry expired offline stream URLs once |
| 119 | 2026-11-19T09:44:27Z | `a5b2b08b67bd753fcf2faf9108f3b1da968bd88b` | ui: style cellular download consent in Pleer1 design |
| 120 | 2026-11-19T09:44:16Z | `60020f3d7890171e75786ebb9fbb4c1812003986` | fix: validate offline audio MIME and cancel removed downloads |
| 121 | 2026-11-19T09:43:49Z | `972f1fb72e442e0dbf7369db3a8c95ae77e0aa6b` | fix: deduplicate complete YouTube resolver requests |
| 122 | 2026-11-19T09:43:25Z | `b90dc4b0bcc1cb96ebd38706b181cd566dba40b1` | fix: validate iOS audio MIME at resolver boundary |
| 123 | 2026-11-19T09:43:15Z | `ee563d9c8198d73ec8d6ac75248b3d9f5d8b4aa5` | fix: restrict iOS JS fallback to AAC MP4 streams |
| 124 | 2026-11-19T09:24:21Z | `51fb09a1a998056e70707837c48b3bbc3f1300bd` | Persist retry-state reset when a download is requeued |
| 125 | 2026-11-19T09:23:53Z | `81e21a2090cd2f8ec3f4c6ca4c683bd4c1115dbe` | Keep retry action available for low-storage failures |
| 126 | 2026-11-19T09:23:45Z | `44af2d6b2926d476555ca650c5c2c86ff3022c16` | Persist offline download failure reasons for clear in-app status |
| 127 | 2026-11-19T09:22:17Z | `55895822432313eb6d6534893e42b1c7aedcac54` | Clean up cached resolver URLs when download jobs are no longer needed |
| 128 | 2026-11-19T09:21:45Z | `3c5eaed3fe529953182bb2fc7aedaaca95a81f8a` | Enforce offline-only mode immediately for active playback |
| 129 | 2026-11-19T09:21:03Z | `fac2d39c81710b51b94252e53d30a857a554cf6d` | Queue favorite download after playback resolution and reuse its stream |
| 130 | 2026-11-19T09:20:53Z | `b23ce58a6e3e01d7aeb479d0419c5a68ce4a204b` | Reuse the playback resolver result for offline download jobs |
| 131 | 2026-11-19T09:20:33Z | `677459e3bfee6a620ca68ea3e2b4b865ea7ca2d8` | Expose a deliberate retry action for failed offline downloads |
| 132 | 2026-11-19T09:20:24Z | `672eaf9cade8b59813963976916428316c7e4670` | Add offline download storage safeguards and persistent retry state |
| 133 | 2026-11-19T09:02:33Z | `cd03f5c960e82e78541e06bae039b3dd9c84a858` | Label offline storage limit as a soft budget |
| 134 | 2026-11-19T09:02:11Z | `811b1af51dafcdeab30d4876edbfabdc4314871f` | Clarify offline library storage budget semantics |
| 135 | 2026-11-19T08:59:53Z | `a3fd3a59a93710ed45f90061088a50967359654a` | Correct Swift interpolation and key-path escaping in offline queue |
| 136 | 2026-11-19T08:59:20Z | `89bc1bcaf9542e5951297620434476fc562282c7` | Preserve selected-track position when filtering an offline queue |
| 137 | 2026-11-19T08:59:17Z | `edcb36b346e75eb84695533dd5b38d58bd905a55` | Clear stale queue status when a favorite is removed |
| 138 | 2026-11-19T08:58:49Z | `06bfe1e801e4935372fdfcf4201b54c4822158fa` | Add native offline-only playback setting |
| 139 | 2026-11-19T08:58:43Z | `84e5b1f956751a99ea1f13c1ff6fee1e2be02ce4` | Add offline-only queue filtering and missing-file skip |
| 140 | 2026-11-19T08:58:19Z | `c5a322f65e2c1108a02da6e412132bc43ef4063b` | Show subtle offline download status in track rows |
| 141 | 2026-11-19T08:58:10Z | `9e16b354e61a0b9ca233f88f41e3611161c67fa3` | Expose subtle per-track offline download states |
| 142 | 2026-11-19T08:57:50Z | `c4e6067a88e8a028f646234e69ed3a1a6b96ec69` | Fix offline cache diagnostics and explicit removal reason |
| 143 | 2026-11-19T08:57:23Z | `4ae65aa4aa725a68eb431226eab0befd93a00e38` | Preserve completed offline downloads and validate catalog entries |
| 144 | 2026-11-19T08:57:07Z | `84ab10f86d876e4ce5e6938d83193724d7c23a34` | Add a dedicated Downloads section to the library |
| 145 | 2026-11-19T08:56:55Z | `86af30390ce031326f5b41868b049d4429488700` | Expose a unified offline library including imported audio |
| 146 | 2026-11-19T08:56:44Z | `3949e786fda02193bf50e603e292f0dd27063685` | Play completed local YouTube downloads regardless of Favorites state |
| 147 | 2026-11-19T08:56:36Z | `cd40545598a01fc391a143f6bf127329d0f44d97` | Keep completed audio downloads independent from Favorites |
| 148 | 2026-11-19T08:49:37Z | `cf77629b4435f94b2753074c65dbb2ab1c703561` | Avoid overlapping download workers during cellular handoff |
| 149 | 2026-11-19T08:48:55Z | `3978533eb17b4730222efd5a4b7eb9f72cff3950` | Keep queued favorite downloads paused until Wi-Fi when cellular is declined |
| 150 | 2026-11-19T08:48:27Z | `4545da0447e5c1b4eee5afdf4908cfecc4deaa0d` | Add native cellular download confirmation alert |
| 151 | 2026-11-19T08:48:25Z | `4864024c2f3f9e194503d5c874123740b518fd64` | Prefer local favorite audio and enqueue missing tracks on playback |
| 152 | 2026-11-19T08:48:23Z | `45daf2f0779ebceb41f90b69824b1d1964b86735` | Queue Favorites audio only when playback starts |
| 153 | 2026-11-19T08:48:20Z | `69e045c7392d423ff2c37bd95c813360739b091d` | Add native cellular-data consent for Favorites audio downloads |
| 154 | 2026-11-19T08:20:46Z | `cb087e592a0c020d922a71e3681926e548826d51` | Keep all newly favorited tracks in serial cache queue |
| 155 | 2026-11-19T08:20:05Z | `38f5e67423c217cf37ac12b709e5781c77e8c8e4` | Enforce favorite audio cache cap during startup |
| 156 | 2026-11-19T08:19:04Z | `cd50b1a37eabc03f954437a106199de3e91af113` | Reuse offline favorite audio and duration metadata |
| 157 | 2026-11-19T08:18:52Z | `8a2d0d2ce8f6a3062835e5777921227787d381bc` | Persist original duration with favorited audio files |
| 158 | 2026-11-19T08:17:51Z | `eff1c2089d73dbd551baa8ca27f64f83852fce6c` | Harden Favorites audio cache queue and cleanup |
| 159 | 2026-11-19T08:17:37Z | `a95760c293390288bf0095b1dc01e788adad0450` | Use YouTube duration for padded audio streams |
| 160 | 2026-11-19T08:08:49Z | `e99f7ad71af61316a4a9d912505296f5b29e7bf3` | Clean interrupted Favorites audio cache downloads |
| 161 | 2026-11-19T08:07:44Z | `10d6602e9e40eb57b99245904946640d5601aa0d` | Play favorited YouTube tracks from local audio cache |
| 162 | 2026-11-19T08:07:37Z | `7cf60147c2b2fac9b0271a03439cf40e72053b4b` | Connect YouTube Favorites changes to audio cache |
| 163 | 2026-11-19T08:07:29Z | `dad80dc86e2c98b326c81e3051fcac2e62296471` | Add bounded persistent cache for favorited YouTube audio |
| 164 | 2026-11-19T07:58:32Z | `c57a71af102a94819cd74288ee196e5867617de0` | Clarify JS resolver automatic cookie handling |
| 165 | 2026-11-19T07:58:22Z | `f3f61ba84bf5f5f93b8b1712fbc499b4ef943a2a` | Add original artwork fallback if resized rendition is unavailable |
| 166 | 2026-11-19T07:57:26Z | `649d0bd5798989cb6a139f443fc2acfef4c2315d` | Use source artwork ratio in full player cover |
| 167 | 2026-11-19T07:57:20Z | `1b8299e8aff5f55aa82cfd700e71fad0e2296340` | Correct artwork resolution interpolation |
| 168 | 2026-11-19T07:57:14Z | `97f5b5bfbbe0dfd3ad1bc5664ddcbf686a6cdd3b` | Fix high-resolution thumbnail URL rewriting |
| 169 | 2026-11-19T07:57:04Z | `7d0a32c3578637586fc6ee39dcf18b3ded97d6b1` | Request high-resolution artwork while preserving aspect ratio |
| 170 | 2026-11-19T07:56:51Z | `0df6c0b15cbed14580af67a32b9cf0e6bb7407f3` | Bound and expire YouTube JS stream cache |
| 171 | 2026-11-19T07:23:32Z | `172fd12f62321b3bfef8870f60e7a400e6869813` | Expand YouTube playability diagnostics for age and bot refusals |
| 172 | 2026-11-19T07:22:49Z | `13e130af886f0fa173ad9fbdab1f5f90cde9494e` | Reuse ephemeral session across YouTube client attempts |
| 173 | 2026-11-19T07:22:27Z | `5b9bf937a6efb0626e4033eda8c2f2f5dc6943de` | Reuse shared URLSession for YouTube resolver requests |
| 174 | 2026-11-19T07:22:21Z | `1f6d207a4c8aa7f7feba1496940b9f030f0167be` | Preserve source artwork aspect ratio in covers |
| 175 | 2026-11-19T07:06:15Z | `72ba733d21a0156faad7a5bada72998076be313a` | Correct JS resolver retry documentation |
| 176 | 2026-11-19T07:06:12Z | `dab45e3e2dcdae26bc779e4ccf72c6a9d753e44b` | Use AVPlayer audio duration for YouTube timeline and watchdog |
| 177 | 2026-11-19T06:50:39Z | `81c38b8e83a96bbfe4d67868076aeb947c3afce3` | Do not auto-skip generic LOGIN_REQUIRED bot checks |
| 178 | 2026-11-19T06:49:41Z | `107016882f466f6598882a0eccb7c82795fec4a3` | Match Musike direct audio format fallback |
| 179 | 2026-11-19T06:49:34Z | `2ab6bfe195b73a25df0efa0584c323af3d7c9d5b` | Align native InnerTube transport with Musike ephemeral sessions |
| 180 | 2026-11-19T06:30:23Z | `2287b783cf3d93b51e0d2ad4dbd420912d16b217` | Harden unavailable reason classification |
| 181 | 2026-11-19T06:30:14Z | `7a689fc2c606f137f63d5643d715f0e51191d437` | Reset skip streak after any playable queue item |
| 182 | 2026-11-19T06:30:08Z | `0c129bc3adcda7aba23bd2e29a8fdce5476c8739` | Skip only definitive unavailable YouTube tracks |
| 183 | 2026-11-19T06:25:30Z | `312b67c6a4dce919fc38e99dd3595b4d7fa98229` | Reset unavailable-track streak on manual previous |
| 184 | 2026-11-19T06:24:55Z | `d56e5a65bb0226ffe1ee3c101c48f37c7832e0fa` | Clean up failed item when skipping YouTube track |
| 185 | 2026-11-19T06:24:38Z | `b9e1454c8131cff98c9d8ce49511e099669f92b8` | Skip unavailable YouTube tracks safely |
| 186 | 2026-11-19T06:10:02Z | `407258453c93bce2c74b3d0d4ec67f57d7d2f730` | Remove duplicate project log; canonical history lives in Pleer1-temporary |
| 187 | 2026-11-19T06:09:16Z | `3e345566af51223e0423fb8d40e9a531d0e8cb8d` | Render library covers in 16:9 landscape frames |
| 188 | 2026-11-19T06:09:11Z | `ad8a7428932dbfd4d97fd62270491b8ed05fdcb4` | Display square artwork in widescreen cover frames |
| 189 | 2026-11-19T06:09:03Z | `31a31d8d326ec5a3b0e7bd883d5f4663c61f9bc8` | Prefer highest-resolution playlist and radio artwork |
| 190 | 2026-11-19T06:08:57Z | `e7a48fcdb0d17f60ea8db30fb76b7bb343514d6b` | Prefer largest available thumbnails in YouTube search |
| 191 | 2026-11-19T06:08:47Z | `78ea7a68a8b7b9770e442d8d282746a3ff230a74` | Choose highest-resolution YouTube artwork source |
| 192 | 2026-11-19T06:01:40Z | `9f58f68fc9cfb3df96fff1250ad7e4bb2dc1b913` | Record latest audit diagnostics and verification limits |
| 193 | 2026-11-19T06:01:19Z | `5e7817439bc279a05da921ad7a21acfcf3ecef36` | Log resolver and AVPlayer duration comparison |
| 194 | 2026-11-19T06:01:17Z | `f98369fc86824632d1f9d5e35699ead0ce2b7c49` | Log restored YouTube favorites on launch |
| 195 | 2026-11-19T06:00:36Z | `85e0650ec3d63a3b1bd6c9f84c92a847460c08ae` | Restore unified Pleer1 project chronology and audit log |
| 196 | 2026-11-19T05:59:39Z | `93722a99c09f9a076eaae198396bb2b928955350` | Persist library state on app deactivation |
| 197 | 2026-11-19T05:59:37Z | `9418940ac39a7d3f7e12de2d5bd2cf027f6bbba5` | Flush saved library state when app backgrounds |
| 198 | 2026-11-19T05:59:25Z | `baa18357e85d7b4bb10d251c37c67dad299c72c3` | Fix WKWebView async resolver bridge return type |
| 199 | 2026-11-19T05:01:39Z | `2cf6f1069ab68dcefd1ed4116d5f2f353ca55947` | Record total YouTube search latency |
| 200 | 2026-11-19T05:01:36Z | `15fda68329c60239fc6772bbbc1df7e0a26995c7` | Improve YouTube diagnostics retention and timing helper |
| 201 | 2026-11-19T04:50:15Z | `54f38389447cfd97af1b9c70c67d77103282430d` | Avoid tuple key-path compatibility risk in search ranking |
| 202 | 2026-11-19T04:49:55Z | `d4b1e8e9aa80ba45b445662d0a8810c5c06c3109` | Tidy search relevance scoring implementation |
| 203 | 2026-11-19T04:49:52Z | `55f666bafe17765779d3a929aa45618f7514333e` | Fix Swift key paths in search ranking tests |
| 204 | 2026-11-19T04:49:30Z | `945b41940fbed2c95f35f950df1ca8e6c78daef5` | Update search tests for collection discovery and relevance order |
| 205 | 2026-11-19T04:49:27Z | `3bad1417bcfa317cba3c1826595ca792a6549616` | Rank merged YouTube search results by intent and relevance |
| 206 | 2026-11-19T04:49:25Z | `e96f2a99073bba310736a4e49bd5984871e55c80` | Implement adaptive YouTube search intent and relevance ranking |
| 207 | 2026-11-19T04:17:48Z | `a707ab346626c09c9b8645bdedff24b444747910` | ci: use integrity-pinned esbuild binary |
| 208 | 2026-11-19T04:17:43Z | `38175f2d60dd67d4879b94dc17064e081073b2d1` | build: pin and verify esbuild runtime bundler |
| 209 | 2026-11-19T04:16:28Z | `0c174079aa7edaf640ab3b803f0c83b546eb6f1b` | chore: clarify bundled runtime initialization error |
| 210 | 2026-11-19T04:16:06Z | `0e6ee950664365783e85ad7b492874941bc0ce14` | fix: align bridge locale and remote config timeout |
| 211 | 2026-11-19T04:15:39Z | `93c1462633096f44ed60ac84b6a7e6cc8ff7eead` | docs: clarify live Musike client config |
| 212 | 2026-11-19T04:15:35Z | `d953c39a345b5f3639a0d4fb1848c598a00aa91f` | chore: remove obsolete temporary bundle ignore |
| 213 | 2026-11-19T04:15:30Z | `216e9f0c3093cd9af565a15926eebeb9c8c89d06` | ci: prepare verified resolver bundle before XcodeGen |
| 214 | 2026-11-19T04:15:26Z | `fc6ba74f0cf1280881c1fc58b523225df3b220ec` | build: remove network-dependent Xcode prebuild phase |
| 215 | 2026-11-19T04:15:22Z | `29225c1de85452616e4f2cc33d4e462efe8632d7` | build: prepare resolver outside Xcode sandbox |
| 216 | 2026-11-19T04:14:46Z | `727f76470a6da07fcca9cc3907f353c1da09165b` | ci: fail fast and verify XcodeGen/esbuild tools |
| 217 | 2026-11-19T04:14:44Z | `7edb55334e3941de346a1eea1e79a538be33f886` | fix: verify bundled classic runtime in WKWebView |
| 218 | 2026-11-19T04:14:24Z | `7c7b23023f634714a616a9c6333517592752ffbb` | ci: install esbuild for bundled resolver runtime |
| 219 | 2026-11-19T04:14:22Z | `f26e83558ebda553a608adf0b082b6baf7a078ed` | build: declare generated standalone runtime resource |
| 220 | 2026-11-19T04:14:19Z | `8a33da91a3c02dcc10d639c99605dc194e25c83a` | build: ignore generated youtubei runtime |
| 221 | 2026-11-19T04:14:16Z | `9027146dc878eb376e1f045322cce936ba14bfdd` | build: bundle youtubei.js as classic WKWebView runtime |
| 222 | 2026-11-19T04:14:10Z | `a12244ca228dd28d6907c380f195dd70e883e3c2` | build: load bundled classic resolver runtime |
| 223 | 2026-11-19T04:14:07Z | `4a85908e70d7bcca99ad1bbbfa829e919e1fb60e` | fix: keep resolver local loading with classic bundled script |
| 224 | 2026-11-19T04:13:27Z | `2c0f2540d210d37ac5a3f4a595d3ac8c997ee99e` | feat: retain Musike live iOS client configuration updates |
| 225 | 2026-11-19T04:13:21Z | `72cc9aada34d0915c56927afdb6cac51b50f533c` | fix: serve resolver modules through same-origin WKURLSchemeHandler |
| 226 | 2026-11-19T03:57:08Z | `8968e993e7c193f964fcf75a873b852f793e6305` | Match Musike locale and stale visitor fallback |
| 227 | 2026-11-19T03:56:39Z | `6fec95c8f5859171c5c918e6942373de8e1d035b` | Match Musike AVPlayer YouTube stream User-Agent |
| 228 | 2026-11-19T03:56:36Z | `2b90e880367c9daa2142600b3723853b19b019ee` | Restore exact Musike native Swift client profiles |
| 229 | 2026-11-19T03:54:59Z | `bf2ceb2c0cef14a72d53b73302dff9ed14b4a29f` | Normalize Swift catch pattern for runtime retry |
| 230 | 2026-11-19T03:54:48Z | `399480013926e9a5da519df2f4435ce42e03b0e7` | Fix retry helper locale argument names |
| 231 | 2026-11-19T03:54:43Z | `bba28e8cd5bc86095aed082643ab7c76d096e80a` | Retry one JS resolve after WebKit process restart |
| 232 | 2026-11-19T03:54:07Z | `a7ebcb39b2313bebc9330b63ba967b15a93edc91` | Match CapacitorHttp locale header in native fetch bridge |
| 233 | 2026-11-19T03:53:11Z | `c3dbce92f1d9068107a36d40c6e7a33f8cfbbf00` | Clean up failed resolver webview before retry |
| 234 | 2026-11-19T03:53:04Z | `421f05a0e792824c4faf05c3c2f0b6ea9bfa12f0` | Attach hidden resolver WKWebView to app window |
| 235 | 2026-11-19T03:52:45Z | `fd8ebc7e0befd0cee0358b741c6c410e59b8b380` | Declare resolver folder reference in resources build phase |
| 236 | 2026-11-19T03:52:38Z | `1793954eed5599ea078506388a3c2c926af4bf39` | Clarify Musike attribution for independent resolver bridge |
| 237 | 2026-11-19T03:52:30Z | `5967feb0260373b30a7ab11302782811fd4cfc88` | Pin Musike client configuration to audited snapshot |
| 238 | 2026-11-19T03:51:32Z | `bb9e88099bc73ece741feee134084bcebba02507` | Remove moved YouTube resolver resource |
| 239 | 2026-11-19T03:51:30Z | `889c0e84f9615fcf53769041d9cff9956199bdb2` | Remove moved YouTube resolver resource |
| 240 | 2026-11-19T03:51:27Z | `8a8b070172ae83076e5cb21e878d702d42cb9669` | Ignore generated browser bundle in root resolver resources |
| 241 | 2026-11-19T03:51:25Z | `311a24405177f668a4590050eabd08bf3d85dbe1` | Use root folder resource to avoid XcodeGen nested-resource path issues |
| 242 | 2026-11-19T03:51:22Z | `262c65bbc4a4fdcf0bba6cdcd6580799fcacb87e` | Generate verified youtubei.js bundle in root resource folder |
| 243 | 2026-11-19T03:51:20Z | `fb33a73559b943647c0705c0ceec9ebdd73c39a9` | Move YouTube resolver resources to XcodeGen-safe folder |
| 244 | 2026-11-19T03:51:17Z | `aae8d5fdbeade3b1c9691247856265fc0d79a07b` | Move YouTube resolver resources to XcodeGen-safe folder |
| 245 | 2026-11-19T03:50:59Z | `a530a56dc91334d586a00925e4323838e610635a` | Restrict JS fallback formats to AVPlayer-compatible audio/mp4 |
| 246 | 2026-11-19T03:50:55Z | `396e662ae2a3d56418eec2e80dbdb1a03031a215` | Keep Swift client profile constants initialized before profile list |
| 247 | 2026-11-19T03:50:36Z | `cdd5a4dbd139fdcd7642f56a837ba4b865c76806` | Use nonpersistent WKWebView data store for resolver |
| 248 | 2026-11-19T03:50:25Z | `afce4ff9df556f5f9063eb2ec90eed6b27026392` | Update youtubei.js notice to pinned 18.3.0 release |
| 249 | 2026-11-19T03:50:23Z | `5b110678b413f98fd03a149f15a77e0286033ee3` | Use per-client User-Agent and context name consistently |
| 250 | 2026-11-19T03:50:10Z | `2ef1a386bbfbd62d9e1ce95875f366f45f325f8c` | Refresh youtubei.js session once on LOGIN_REQUIRED |
| 251 | 2026-11-19T03:50:02Z | `53973fabad50dc0c6a0ea383b57bb2827ed616b1` | Align Swift InnerTube client profiles with youtubei.js 18.3.0 |
| 252 | 2026-11-19T03:49:59Z | `f471351b8f877466b24c99a8588fbb9710c5f8b4` | Update XcodeGen build phase dependency to youtubei.js 18.3.0 |
| 253 | 2026-11-19T03:49:57Z | `a4e359d63ba38cdebfc22723e1ea323cbb9e63d4` | Pin youtubei.js 18.3.0 with verified package integrity |
| 254 | 2026-11-19T03:27:09Z | `5dce04c6e09a40de20e3487a9851ba459c3f76c7` | Use an in-memory youtubei.js cache in the WKWebView runtime |
| 255 | 2026-11-19T03:26:34Z | `055cf5878a5fbf6962e88f57785a606f29f3d2a5` | Integrate Musike-style youtubei.js fallback on iOS |
| 256 | 2026-11-19T00:59:02Z | `a64ced41faf9fc93ec187c2d071e904bf0d1692b` | Restore collections in ordinary YouTube search |
| 257 | 2026-11-19T00:21:32Z | `33697a5904646e7fc3f442d8580afaff7f9da364` | Fix Codemagic IPA artifact path and add diagnostics |
| 258 | 2026-11-18T23:59:00Z | `ec7bfe8f0fef22eb5fe0c2eb28573309de484db4` | Add manual Codemagic unsigned iOS device IPA workflow |
| 259 | 2026-11-18T19:17:08Z | `3e9ff0516df8bd07ac21ba3c96e493a6b2b45534` | Disable automatic IPA builds on every Lab push |
| 260 | 2026-11-18T19:08:31Z | `616f54ee3c5b6b0972b6731c8ab2de8a3163fede` | Remove duplicate Lab journal; use canonical ROADMAP and decision/error log |
| 261 | 2026-11-18T19:08:29Z | `e46009c4b08a4604186ef533506ed455eefe45cf` | Remove duplicate Lab journal; use canonical ROADMAP and decision/error log |
| 262 | 2026-11-18T19:02:25Z | `33c3849092f27344cc01862e9a75eec4b2f9e664` | Add Pleer1 build and verification log |
| 263 | 2026-11-18T19:02:23Z | `bf42880e1fc333029e33aed4e9366b26ad3f83a8` | Add Pleer1 project decision journal |
| 264 | 2026-11-18T19:02:21Z | `9e54866acfbd0b140dc1a102d536140878072ccd` | Run device IPA build on isolated YouTube fix branch |
| 265 | 2026-11-18T19:01:45Z | `79ab6356de113946a6acc83252ccfd6bfb183b09` | Preserve Cyrillic diacritics in search intent normalization |
| 266 | 2026-11-18T19:01:43Z | `666c0b33de0afce4360b62a1536edf2dadc6d0ac` | Fix HTML fallback standalone video deduplication |
| 267 | 2026-11-18T19:01:41Z | `57efe0a326f043a961c9df90b77ec64eae3274ce` | Fix InnerTube standalone video deduplication |
| 268 | 2026-11-18T13:02:56Z | `b8e0db19621340cb86dddb03ed433875ba7435e2` | Add search correlation ID to HTML parser summary |
| 269 | 2026-11-18T12:56:10Z | `cf751ec81c6b8871306e903ff4d31b1d5d765cfc` | Fix collection intent filtering and correlate search diagnostics |
| 270 | 2026-11-18T12:55:00Z | `16d6416f922c606f75c6f7f31c47004626ccb95c` | Separate YouTube track search from playlist and Mix discovery |
| 271 | 2026-11-18T11:48:37Z | `bc491d8d55b8a669520586764c52c18b567329d1` | Align media support with Pleer1 working branch |
| 272 | 2026-11-18T11:48:15Z | `0cc722efe85dc959e14b46ae8eff973c3f12fa1a` | Restore Pleer1 app icon asset in integration branch |
| 273 | 2026-11-18T11:47:38Z | `31694bc6096e2e80d831ee9d4a3e095bb30d8a9b` | Align Track model with Pleer1 YouTube working branch |
| 274 | 2026-11-18T11:47:16Z | `bba7125672da0c3a69809cee1b12861fc458e819` | Align Lab XcodeGen project with Pleer1 working branch |
| 275 | 2026-11-18T11:47:08Z | `4f491c4325fda4c98c9571fc5ce1c474d0596414` | Import Pleer1 YouTube module: plei/UITests/SearchSmokeTests.swift |
| 276 | 2026-11-18T11:47:05Z | `346668c683bb0b162eeff072313213a99f002397` | Import Pleer1 YouTube module: plei/Sources/YouTubePlaylistEngine.swift |
| 277 | 2026-11-18T11:46:58Z | `6003a880397da012dd66a26897904c508cf0a15b` | Import Pleer1 YouTube module: plei/Sources/YouTubeHTMLSearch.swift |
| 278 | 2026-11-18T11:46:55Z | `84f35b0bd6726700c4e5ce9b1ab5ff3f9933533c` | Import Pleer1 YouTube module: plei/Sources/YouTubeEngine.swift |
| 279 | 2026-11-18T11:46:51Z | `9964e06de2a2c4d3e4fa0a280c610f7ece896b48` | Import Pleer1 YouTube module: plei/Sources/YouTubeDiagnostics.swift |
| 280 | 2026-11-18T11:46:31Z | `2fdee51c4959aa262bec60c8abb469f428a71ba2` | Import Pleer1 working source: plei/Sources/Views.swift |
| 281 | 2026-11-18T11:46:27Z | `5c3c6f8ff1ad845ae77b6471226bc66d6a1f0b14` | Import Pleer1 working source: plei/Sources/Store.swift |
| 282 | 2026-11-18T11:46:23Z | `69fd37a2feb98c0c9bb5ae1ed4d3256289cae9ad` | Import Pleer1 working source: plei/Sources/Providers.swift |
| 283 | 2026-11-18T11:46:19Z | `1722d3398e89a06de38bd2169869057973708751` | Import Pleer1 working source: plei/Sources/Player.swift |
| 284 | 2026-11-18T11:46:15Z | `ffe36efcba2f2ddb54ea78174db2b5afc97216e6` | Import Pleer1 working source: THIRD-PARTY-NOTICES.md |
| 285 | 2026-11-18T11:46:12Z | `528ee5b256b269675cf3ee8109eec604e7748851` | Import Pleer1 working source: .github/workflows/ios-simulator-smoke.yml |
| 286 | 2026-11-17T10:42:02Z | `6de22da8ebd089e71cf6b9df34edeb915b636063` | Correct audit JSON error reporting |
| 287 | 2026-11-17T10:41:56Z | `9b0a9249de5328966c7a308fe0588b6c218539f9` | Fix Python syntax in evidence-checked audit workflow |
| 288 | 2026-11-17T10:41:47Z | `2680cb2d0c9ac3dc09729b3180bbe8e5f1866288` | Upgrade companion audit to Qwen3 8B with citation validation |
| 289 | 2026-11-17T09:51:53Z | `a39c9c2803c04f91c00466b5c5d2540fbffbe391` | Focus companion audit on intermittent auto-advance |
| 290 | 2026-11-17T09:05:51Z | `8990ae463352a9b812fefad1d0462468575407ec` | Capture audit output and include source dispatch path |
| 291 | 2026-11-17T09:05:39Z | `f9d50c92cf6ed51526d0a01ca92f3c8128a7cc7a` | Replace looping companion agent with one-shot local Qwen audit |
| 292 | 2026-11-17T08:41:47Z | `40fd3b512669ef829160cf08f9f36692db47a82c` | chore: enforce one-pass companion audit |
| 293 | 2026-11-17T08:08:31Z | `cbc439edb9e7029251643360c7b4fad07be80e92` | fix: add dedicated manual companion audit workflow |
| 294 | 2026-11-17T08:02:43Z | `69990ee3cb6dd82384770ee1b3bb63868a2ad7f6` | fix: focus companion audit and allow completion time |
| 295 | 2026-11-16T23:24:58Z | `2fb64326f14a46dfb05e8d26000efad6076487e6` | Optimize private snapshot audit launcher |
| 296 | 2026-11-16T22:53:47Z | `3e69614a5b6c3bd3fa10f96052acc8f26c2e0fb6` | Add private snapshot audit workflow launcher |
| 297 | 2026-11-16T06:03:22Z | `849611a7b85510b4ee1efd59d67d91742de2a1ad` | Import current Pleer1 as integration baseline |
| 298 | 2026-11-16T06:02:29Z | `c0e2d757c0cb4936b5ce1c875d6adbe9dbe7f535` | Initialize Pleer1-Next laboratory |

## Audit method and status

For each commit, the audit records: parent/context; exact changed files and meaningful hunks; intent; whether current branch HEAD retains, supersedes, or reverts the change; current source evidence; tests/build/device evidence; and follow-up status. Tiny mechanical fixes and generated-file moves are still inventoried, but can be grouped by a common functional change when their diffs are equivalent.

Completed in the current review: complete 298-commit inventory; individual commit metadata/diff retrieval; detailed source reviews for Library/Recent/Store/Player/download/network, duration/Repeat One/seek, YTM catalog/JS resolver/WebKit, and known revert reconciliation.

Still open: exhaustive semantic reconciliation of all remaining commits and all relevant hunks against HEAD; verify SearchModel/request identity; reconcile the pre-YTM YouTube search, Mix/playlist, artwork, diagnostics, imports, and project/build workflow changes; assign four-level status per feature; final gap list and priority order. No source changes and no new build are part of this audit.


## Semantic reconciliation progress — 20 November 2026

**Status:** not complete. The 298-commit inventory remains intact. The following ranges have now had their diffs reviewed in functional batches and compared with current source evidence: 1–47 (YTM/catalog and initial integration), 48–77 (seek, artwork, library and revert sequence), 78–162 (UI/library, offline downloads, network/cellular, resolver coordination, skip and duration changes), 163–224 (cache, artwork, search ranking, persistence/diagnostics, YTM runtime build integration), 225–254 (WKWebView bridge, resource relocation, native client profile and JS fallback integration), and 255–298 (search parser fixes, baseline import, workflow/audit infrastructure). Commit 268 was separately checked for HTML search diagnostic correlation. Earlier passes also fetched metadata/diffs for the full inventory.

**Important distinction:** batch review of diffs is not yet a completed per-commit retained/superseded/reverted reconciliation. The remaining audit work is to explicitly map each commit to current HEAD evidence and tests, especially all small mechanical commits, reverts, and the earliest imported baseline commits; then verify no requirement or feature fell between branches. Do not mark all 298 as semantically closed yet.

**New source-level conclusions:** (1) current duration policy is resolver-metadata authoritative and can finish UI/watchdog near 218 s while AVPlayer item duration is ~435 s; actual audible EOF remains unproven; (2) Repeat One source path sets plannedNext to current index and user reports it likely works, so treat as regression test, not known P0 defect; (3) «Моё» navigation is already source-implemented as Favorites DisclosureGroup + dedicated Downloads/Recent screens; (4) offline download/cellular/route logic is present but latest HEAD lacks full device evidence; (5) local import/delete policy gaps remain; (6) current build preparation is explicit workflow step and project.yml has no duplicate prebuild script.

**Next audit focus:** finish one-to-one reconciliation for every commit and compare the old Roadmap checklists against current HEAD, with particular attention to early baseline features, pre-YTM offline/import/search work, revert chains, and actual CI run evidence. No source edits or builds until the audit gate is satisfied.


### Revert chain status — 20 November 2026

- Commit 96b54c5 reverted combined library deduplication; later 1bef38f and a623bce reintroduced it, and current Store.library deduplicates by Track.id.
- Commit 5ec6207 reverted Favorites-only display and temporarily merged downloadedTracks into Favorites; later 9313815 and 6dc1ee6 restored Favorites-only content, and current FavoritesView uses store.favorites.
- Commit dd9f7ca reverted recent-seek-to-end classification fields and typed completion trigger. Commit 1cd735 resets the YouTube watchdog baseline after seek but does not restore the classification. Current Player has seek source diagnostics but no lastSeekTarget/lastSeekRequestedAt correlation; finishCurrentItem has no trigger/source argument.
- **Current source gap:** manual seek to end may flow into the same completion/advance path as natural AVPlayer EOF. This does not make manual seek a valid natural-end test. Expected behavior for manual seek-to-end must be decided before a fix.


### Recent history semantics checked — 20 November 2026

- RecentView is a direct list screen.
- Player.load() records history before resolver/AVPlayer readiness; failed tracks may appear in Recent. Store.addHistory() does not refresh listenedAt when the same ID is already first. HistoryEntry does not store duration and retains only metadata/local filename reference, not audio bytes or YouTube watch URL.
- Expected semantics (“attempted/selected” vs “actually started playing”) remain a product decision. No source change.


### GitHub Actions run evidence — 20 November 2026

- Latest 100 branch runs: 10/10 source-validation failures, 9/9 simulator smoke failures, 81/81 companion-audit failures.
- Latest validation/simulator runs on HEAD a69ddc5 ended in 4s/11s; job metadata has no steps/log URL and job log fetch returns 404. No evidence tests or builds executed. Cause is not exposed; do not label as source failure or assume runner exhaustion.
- No rerun/build was triggered. Codemagic Build #5 remains separate successful IPA evidence.
