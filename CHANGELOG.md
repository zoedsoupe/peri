# Changelog

All notable changes to this project will be documented in this file.

## [0.8.3](https://github.com/zoedsoupe/peri/compare/v0.11.2...v0.8.3) (2026-08-17)


### Features

* {:coerce, source, target} directive with decode/encode ([40ef5f4](https://github.com/zoedsoupe/peri/commit/40ef5f439d74584de1e7063e5f8c8cd83f16ff4a))
* `:schema` validator that can accept additional keys ([#37](https://github.com/zoedsoupe/peri/issues/37)) ([098be96](https://github.com/zoedsoupe/peri/commit/098be96a106671119bc7ea83d6fe9099a2319c36))
* add :meta wrapper and schema-level meta opts ([#47](https://github.com/zoedsoupe/peri/issues/47)) ([b63584c](https://github.com/zoedsoupe/peri/commit/b63584c6ef61c81521b991210129b175a616afd5))
* add :multi directive for tagged unions ([#51](https://github.com/zoedsoupe/peri/issues/51)) ([4727871](https://github.com/zoedsoupe/peri/commit/47278718d4079977742df9c69f9e7476c9c4be3d))
* add :ref directive for recursive and cross-module schemas ([#50](https://github.com/zoedsoupe/peri/issues/50)) ([b5c778b](https://github.com/zoedsoupe/peri/commit/b5c778bee3bd5d1cb317ff05d6281323bf8a575d))
* add ci ([16cf116](https://github.com/zoedsoupe/peri/commit/16cf116b6e89e1d06c65ac15e26428475b305c44))
* add JSON Schema (Draft 7) bidirectional conversion ([#49](https://github.com/zoedsoupe/peri/issues/49)) ([7a78a14](https://github.com/zoedsoupe/peri/commit/7a78a14eda19abe6952e0ec5e852d5002ac78fc5))
* add MFA support for transform, default and dependent directives ([8928e59](https://github.com/zoedsoupe/peri/commit/8928e59d68a5183f415caa4537ce2d16fb7c5281))
* add Peri.walk/2 schema rewriter ([#53](https://github.com/zoedsoupe/peri/issues/53)) ([1464f3f](https://github.com/zoedsoupe/peri/commit/1464f3f77f27a9471f80bd07532db96943dc444c))
* add typespecs ([802e9f6](https://github.com/zoedsoupe/peri/commit/802e9f66390991dbf119046ab14708d89f02b16c))
* basic jason protocol support ([9031b1e](https://github.com/zoedsoupe/peri/commit/9031b1e42bea82c10e081646f18369c8dca6434a))
* coerce shorthand, atom!/enum/literal targets, split lists ([2dbb994](https://github.com/zoedsoupe/peri/commit/2dbb994eb4a4ca7bef08238189477a125eb81f47))
* compact schema summaries in error messages ([#57](https://github.com/zoedsoupe/peri/issues/57)) ([e2b6c0b](https://github.com/zoedsoupe/peri/commit/e2b6c0b5842a6e4e3a4418d79d4010f7bea78aaf))
* cond type receives whole data and should be treated as required ([336316c](https://github.com/zoedsoupe/peri/commit/336316c3b9ab2dc4cc79ffaa51333d9a5c8742e9))
* data generation ([c85b972](https://github.com/zoedsoupe/peri/commit/c85b9720e972ea50e6caec0d8a30d67301b7ce97))
* data generations ([ecc2d2c](https://github.com/zoedsoupe/peri/commit/ecc2d2ca07147fd1d2c9262ba9f7de7ee1f0f02f))
* default values type ([821935f](https://github.com/zoedsoupe/peri/commit/821935f6198531985a752d9582e6abb55e8f844e))
* ecto integration ([#18](https://github.com/zoedsoupe/peri/issues/18)) ([8d3fe0d](https://github.com/zoedsoupe/peri/commit/8d3fe0d0eb0cef328ab550ecb15dad252c692ecd))
* elixir 1.20.0 compiler fixes ([5b93739](https://github.com/zoedsoupe/peri/commit/5b93739fc6dbf9c80cdbac4105289dcb92b623d5))
* error humanize, missing-key spellcheck, legible oneof summaries ([94f1a75](https://github.com/zoedsoupe/peri/commit/94f1a757fb6e1fef75747bc923ae613ee6594f37))
* extend JSON Schema meta vocab to Draft-7 keywords ([#59](https://github.com/zoedsoupe/peri/issues/59)) ([0f832a2](https://github.com/zoedsoupe/peri/commit/0f832a21eb676b70e238eb0d916839c068636dee))
* handle structs as data ([#9](https://github.com/zoedsoupe/peri/issues/9)) ([859a0fd](https://github.com/zoedsoupe/peri/commit/859a0fdff9781f93bab913095e8ef6c2ec446256))
* implement schema validation, bang functions and improve error inspecting ([fc061f0](https://github.com/zoedsoupe/peri/commit/fc061f055fbb93ccce75201f3c6fc19579043d0f))
* improve error handling ([f4d504b](https://github.com/zoedsoupe/peri/commit/f4d504b3ca3f4c24c21512e4a59fd4d60a550d5b))
* list constraints (:min/:max/:unique) and :multiple_of ([#56](https://github.com/zoedsoupe/peri/issues/56)) ([859255d](https://github.com/zoedsoupe/peri/commit/859255d911c14af795a2d69f9a6d1bded7c30ea2))
* multiple field dependencies dependent type ([1be99ef](https://github.com/zoedsoupe/peri/commit/1be99ef5abc1128643a2a8b50be750bb28ce7622))
* multiple validator options ([#35](https://github.com/zoedsoupe/peri/issues/35)) ([2c5ec2f](https://github.com/zoedsoupe/peri/commit/2c5ec2fccdb90663372f90fe6d21ec9ce9f48133))
* new schema types for map and literal ([#22](https://github.com/zoedsoupe/peri/issues/22)) ([feaf2c7](https://github.com/zoedsoupe/peri/commit/feaf2c7cecee6f03e825f2cd2c0340049e3ac80f))
* pass current elem in dependent/cond valdiations ([#28](https://github.com/zoedsoupe/peri/issues/28)) ([324b6f4](https://github.com/zoedsoupe/peri/commit/324b6f44577fe22ec74b80b9e068edf6b765793c))
* pass root data to the dependet and cond types ([b79dfbd](https://github.com/zoedsoupe/peri/commit/b79dfbd0b1ca18a74cc283c620e6c85b7abd5a8e))
* per-field custom error overrides + i18n hook ([#52](https://github.com/zoedsoupe/peri/issues/52)) ([838514c](https://github.com/zoedsoupe/peri/commit/838514cff8c9b074dbfca79cd269d20b48ddb7b7))
* per-field gen: override for StreamData generation ([#54](https://github.com/zoedsoupe/peri/issues/54)) ([029da56](https://github.com/zoedsoupe/peri/commit/029da561cb39f62ae6f9e9a8145e4bb09887706d))
* permissive schema ([#33](https://github.com/zoedsoupe/peri/issues/33)) ([3b4b137](https://github.com/zoedsoupe/peri/commit/3b4b1372d1ec00d9b38959549995d6654786e9a5))
* Phoenix form bridge via Peri.Form and FormData protocol ([b791bb0](https://github.com/zoedsoupe/peri/commit/b791bb0e11171abd465329d2b38a961a075d5762))
* schema composition with merge/select/except ([898eeda](https://github.com/zoedsoupe/peri/commit/898eeda279b79970e57529ffb0cacf2770ece675))
* split out `validation_result` from `validation` type for reuse ([#34](https://github.com/zoedsoupe/peri/issues/34)) ([b3bd773](https://github.com/zoedsoupe/peri/commit/b3bd77324398e3415345820f16877d3d77cc50f2))
* transform type ([848eea7](https://github.com/zoedsoupe/peri/commit/848eea72b1717345d32ffce69790381621c5337c))
* typed enum and exclude_meta_keys JSON Schema opt ([#62](https://github.com/zoedsoupe/peri/issues/62)) ([82d3edd](https://github.com/zoedsoupe/peri/commit/82d3eddf58bd98d8e0271f3a418dc80599f2c315))
* use Peri.Parser to manage schema parsing state ([68fa43f](https://github.com/zoedsoupe/peri/commit/68fa43f776182ce747644fb29166b05c52b517f9))


### Bug Fixes

* ambigous numeric validation, integers allowed floats and vice-versa ([993eabf](https://github.com/zoedsoupe/peri/commit/993eabf2c77fa06bf5865deb8c584a9ea622a89c)), closes [#72](https://github.com/zoedsoupe/peri/issues/72)
* build phoenix test schema at runtime for Elixir &lt; 1.19 ([c9d7693](https://github.com/zoedsoupe/peri/commit/c9d7693bc4e1ed3a56997966f73a7ac77dbd1ac2))
* clear errors for dependent callback contract breaches ([2423cd9](https://github.com/zoedsoupe/peri/commit/2423cd9b996d44607cfa99cff84d4b5a580a075b))
* correctly handle multiple struct fields as input data ([3cfe428](https://github.com/zoedsoupe/peri/commit/3cfe4282bfd6cde105b6f7b15e68a49567047772))
* credo warnings ([b0c906c](https://github.com/zoedsoupe/peri/commit/b0c906c1e8a14e19a429d7c81d6dd97acde477e7))
* decode JSON Schema number/integer to either int|float per spec ([#68](https://github.com/zoedsoupe/peri/issues/68)) ([dc88c0f](https://github.com/zoedsoupe/peri/commit/dc88c0f17c9114444c72cce148dc2cbb88204274))
* default appliance on nested partial required schema ([#45](https://github.com/zoedsoupe/peri/issues/45)) ([01a6ca2](https://github.com/zoedsoupe/peri/commit/01a6ca25370f9748fa6cccb271076122387c948e))
* dependent validation behavior ([#26](https://github.com/zoedsoupe/peri/issues/26)) ([e815b20](https://github.com/zoedsoupe/peri/commit/e815b200a09f9424e2d2317569b7cf6be4c180de))
* do not cast string/atom enum values ([1d11647](https://github.com/zoedsoupe/peri/commit/1d11647b2f6c9eae2edaf98f38b62c0131825c6b))
* do not fetch peri parser on raw data schemas ([#10](https://github.com/zoedsoupe/peri/issues/10)) ([32aa540](https://github.com/zoedsoupe/peri/commit/32aa54029f81f90b91e18e04f735db5f7022dae8))
* do not raise on schemas with string keys ([#4](https://github.com/zoedsoupe/peri/issues/4)) ([266b5a2](https://github.com/zoedsoupe/peri/commit/266b5a27f9278578b92cf8cdc0f95a19cda2d08b))
* error_to_map nil content handling ([#69](https://github.com/zoedsoupe/peri/issues/69)) ([a140299](https://github.com/zoedsoupe/peri/commit/a140299ad355d5df07e2a85add96b11ea52c59b3))
* form list_entries crash on non-numeric param keys ([a8de6a2](https://github.com/zoedsoupe/peri/commit/a8de6a2688ff3f3dbb718a6edbfaff3420438a18))
* humanize deep_merge crash on prefix-colliding error paths ([6b7f686](https://github.com/zoedsoupe/peri/commit/6b7f6867e4832c7edb590db59695c79b344c04bc))
* make :either behave consistently with :oneof for nested ([#21](https://github.com/zoedsoupe/peri/issues/21)) ([d494847](https://github.com/zoedsoupe/peri/commit/d49484746ff8f8c022f03917de5a9004b4234608))
* nested schema on lists filter data and respect schema definition ([#32](https://github.com/zoedsoupe/peri/issues/32)) ([792fc9c](https://github.com/zoedsoupe/peri/commit/792fc9ca16a0810a1683d8c22e3aeaa60b1bb3e9))
* predictable JSON Schema decoder keys via :keys opt ([#66](https://github.com/zoedsoupe/peri/issues/66)) ([ce9caeb](https://github.com/zoedsoupe/peri/commit/ce9caeba35ab706e00fc2b4cfdc8b383b5dc39a9))
* schema with nested required fields ([#41](https://github.com/zoedsoupe/peri/issues/41)) ([69e843a](https://github.com/zoedsoupe/peri/commit/69e843a528524e463bb2e9020eecc1fd39398362))
* some corrections for 0.2.10 ([b212bc1](https://github.com/zoedsoupe/peri/commit/b212bc1982f74f779439a01ad0deb1ba8cf29afb))
* typos ([#25](https://github.com/zoedsoupe/peri/issues/25)) ([2e9782d](https://github.com/zoedsoupe/peri/commit/2e9782d2d1ec1c4c27905335140ea01469f972e9))


### Documentation

* slim README, moduledoc reads it via File.read! ([068f987](https://github.com/zoedsoupe/peri/commit/068f98721aea8bdf4e974d80bb4e1f0ea465bc5e))


### Miscellaneous Chores

* fix compilation warning ([d2eeaa7](https://github.com/zoedsoupe/peri/commit/d2eeaa7c48d91ea1153cc49b9d76bab289ca525f))
* release 0.10.0 ([#74](https://github.com/zoedsoupe/peri/issues/74)) ([7718355](https://github.com/zoedsoupe/peri/commit/77183556af88aaf9bf12b1db280250040688a53d))
* release 0.11.0 ([#75](https://github.com/zoedsoupe/peri/issues/75)) ([a004fa2](https://github.com/zoedsoupe/peri/commit/a004fa2443bf19afdf32c953fcb6a51b89503386))
* release 0.11.1 ([#76](https://github.com/zoedsoupe/peri/issues/76)) ([3ef9615](https://github.com/zoedsoupe/peri/commit/3ef9615ec618aa0a0c7c0ccb6c8cb9c3ce5dd0e5))
* release 0.11.2 ([#77](https://github.com/zoedsoupe/peri/issues/77)) ([15c9190](https://github.com/zoedsoupe/peri/commit/15c91900d5fde3e25ff4430ad1356da765bb870b))
* release 0.6.0 ([#39](https://github.com/zoedsoupe/peri/issues/39)) ([1580790](https://github.com/zoedsoupe/peri/commit/1580790f9845205d2fc31565dc3a5b3e86d561c6))
* release 0.6.1 ([#42](https://github.com/zoedsoupe/peri/issues/42)) ([32427c4](https://github.com/zoedsoupe/peri/commit/32427c46798904f5f617bcebb1ed1a7cfb7611ab))
* release 0.6.2 ([#46](https://github.com/zoedsoupe/peri/issues/46)) ([ce63d6a](https://github.com/zoedsoupe/peri/commit/ce63d6aa1bceadb13100bce97789b1aa216d5509))
* release 0.7.0 ([#48](https://github.com/zoedsoupe/peri/issues/48)) ([3e4c9f2](https://github.com/zoedsoupe/peri/commit/3e4c9f225b2a51f56135dafa2a0403fda8c6dcaa))
* release 0.8.0 ([#55](https://github.com/zoedsoupe/peri/issues/55)) ([8a19d5c](https://github.com/zoedsoupe/peri/commit/8a19d5cf376da9fbdfd3bab7031c133d242460b4))
* release 0.8.1 ([#58](https://github.com/zoedsoupe/peri/issues/58)) ([e3f43fc](https://github.com/zoedsoupe/peri/commit/e3f43fce1adc4c1f180a8b0b39481b84c537b4ff))
* release 0.8.2 ([#61](https://github.com/zoedsoupe/peri/issues/61)) ([9cad3cc](https://github.com/zoedsoupe/peri/commit/9cad3cc7736e75585460cd22e18017946f9f9de1))
* release 0.8.3 ([#63](https://github.com/zoedsoupe/peri/issues/63)) ([8e528c2](https://github.com/zoedsoupe/peri/commit/8e528c2614d812076299d0c26958c0f59fb2ae06))
* release 0.8.4 ([#67](https://github.com/zoedsoupe/peri/issues/67)) ([a30fcf0](https://github.com/zoedsoupe/peri/commit/a30fcf0818518285dcb2712d5f4cf82b9a3e4496))
* release 0.8.5 ([#70](https://github.com/zoedsoupe/peri/issues/70)) ([b8e2cfc](https://github.com/zoedsoupe/peri/commit/b8e2cfc99c8c3e295012de950ca75ffb37d54e11))
* release 0.9.0 ([#71](https://github.com/zoedsoupe/peri/issues/71)) ([f1a4c25](https://github.com/zoedsoupe/peri/commit/f1a4c254d9a9e1bc9c04f3d58542db876af611cb))
* release 0.9.1 ([#73](https://github.com/zoedsoupe/peri/issues/73)) ([e0c95d3](https://github.com/zoedsoupe/peri/commit/e0c95d353bea63d6b4d782e332cf468b3417d6b3))


### Continuous Integration

* add auto hex publish ([3d7e67a](https://github.com/zoedsoupe/peri/commit/3d7e67a7986cd6cbaaf9df193c75e95564e02548))
* add ex_doc to test ([0f951fc](https://github.com/zoedsoupe/peri/commit/0f951fcaa6e59720c5ed2c7306f4ac6985480cb6))

## [0.11.2](https://github.com/zoedsoupe/peri/compare/v0.11.1...v0.11.2) (2026-08-17)


### Bug Fixes

* clear errors for dependent callback contract breaches ([2423cd9](https://github.com/zoedsoupe/peri/commit/2423cd9b996d44607cfa99cff84d4b5a580a075b))

## [0.11.1](https://github.com/zoedsoupe/peri/compare/v0.11.0...v0.11.1) (2026-08-15)


### Bug Fixes

* build phoenix test schema at runtime for Elixir &lt; 1.19 ([c9d7693](https://github.com/zoedsoupe/peri/commit/c9d7693bc4e1ed3a56997966f73a7ac77dbd1ac2))

## [0.11.0](https://github.com/zoedsoupe/peri/compare/v0.10.0...v0.11.0) (2026-08-15)


### Features

* coerce shorthand, atom!/enum/literal targets, split lists ([2dbb994](https://github.com/zoedsoupe/peri/commit/2dbb994eb4a4ca7bef08238189477a125eb81f47))


### Documentation

* slim README, moduledoc reads it via File.read! ([068f987](https://github.com/zoedsoupe/peri/commit/068f98721aea8bdf4e974d80bb4e1f0ea465bc5e))

## [0.10.0](https://github.com/zoedsoupe/peri/compare/v0.9.1...v0.10.0) (2026-08-11)


### Features

* {:coerce, source, target} directive with decode/encode ([40ef5f4](https://github.com/zoedsoupe/peri/commit/40ef5f439d74584de1e7063e5f8c8cd83f16ff4a))
* error humanize, missing-key spellcheck, legible oneof summaries ([94f1a75](https://github.com/zoedsoupe/peri/commit/94f1a757fb6e1fef75747bc923ae613ee6594f37))
* Phoenix form bridge via Peri.Form and FormData protocol ([b791bb0](https://github.com/zoedsoupe/peri/commit/b791bb0e11171abd465329d2b38a961a075d5762))
* schema composition with merge/select/except ([898eeda](https://github.com/zoedsoupe/peri/commit/898eeda279b79970e57529ffb0cacf2770ece675))


### Bug Fixes

* form list_entries crash on non-numeric param keys ([a8de6a2](https://github.com/zoedsoupe/peri/commit/a8de6a2688ff3f3dbb718a6edbfaff3420438a18))
* humanize deep_merge crash on prefix-colliding error paths ([6b7f686](https://github.com/zoedsoupe/peri/commit/6b7f6867e4832c7edb590db59695c79b344c04bc))

## [0.9.1](https://github.com/zoedsoupe/peri/compare/v0.9.0...v0.9.1) (2026-08-07)


### Bug Fixes

* ambigous numeric validation, integers allowed floats and vice-versa ([993eabf](https://github.com/zoedsoupe/peri/commit/993eabf2c77fa06bf5865deb8c584a9ea622a89c)), closes [#72](https://github.com/zoedsoupe/peri/issues/72)

## [0.9.0](https://github.com/zoedsoupe/peri/compare/v0.8.5...v0.9.0) (2026-06-10)


### Features

* elixir 1.20.0 compiler fixes ([5b93739](https://github.com/zoedsoupe/peri/commit/5b93739fc6dbf9c80cdbac4105289dcb92b623d5))

## [0.8.5](https://github.com/zoedsoupe/peri/compare/v0.8.4...v0.8.5) (2026-05-23)


### Bug Fixes

* error_to_map nil content handling ([#69](https://github.com/zoedsoupe/peri/issues/69)) ([a140299](https://github.com/zoedsoupe/peri/commit/a140299ad355d5df07e2a85add96b11ea52c59b3))

## [0.8.4](https://github.com/zoedsoupe/peri/compare/v0.8.3...v0.8.4) (2026-05-04)


### Bug Fixes

* decode JSON Schema number/integer to either int|float per spec ([#68](https://github.com/zoedsoupe/peri/issues/68)) ([dc88c0f](https://github.com/zoedsoupe/peri/commit/dc88c0f17c9114444c72cce148dc2cbb88204274))
* predictable JSON Schema decoder keys via :keys opt ([#66](https://github.com/zoedsoupe/peri/issues/66)) ([ce9caeb](https://github.com/zoedsoupe/peri/commit/ce9caeba35ab706e00fc2b4cfdc8b383b5dc39a9))

## [0.8.3](https://github.com/zoedsoupe/peri/compare/v0.8.2...v0.8.3) (2026-04-29)


### Features

* typed enum and exclude_meta_keys JSON Schema opt ([#62](https://github.com/zoedsoupe/peri/issues/62)) ([82d3edd](https://github.com/zoedsoupe/peri/commit/82d3eddf58bd98d8e0271f3a418dc80599f2c315))

## [0.8.2](https://github.com/zoedsoupe/peri/compare/v0.8.1...v0.8.2) (2026-04-29)


### Features

* extend JSON Schema meta vocab to Draft-7 keywords ([#59](https://github.com/zoedsoupe/peri/issues/59)) ([0f832a2](https://github.com/zoedsoupe/peri/commit/0f832a21eb676b70e238eb0d916839c068636dee))

## [0.8.1](https://github.com/zoedsoupe/peri/compare/v0.8.0...v0.8.1) (2026-04-28)


### Miscellaneous Chores

* fix compilation warning ([d2eeaa7](https://github.com/zoedsoupe/peri/commit/d2eeaa7c48d91ea1153cc49b9d76bab289ca525f))

## [0.8.0](https://github.com/zoedsoupe/peri/compare/v0.7.0...v0.8.0) (2026-04-28)


### Features

* compact schema summaries in error messages ([#57](https://github.com/zoedsoupe/peri/issues/57)) ([e2b6c0b](https://github.com/zoedsoupe/peri/commit/e2b6c0b5842a6e4e3a4418d79d4010f7bea78aaf))
* list constraints (:min/:max/:unique) and :multiple_of ([#56](https://github.com/zoedsoupe/peri/issues/56)) ([859255d](https://github.com/zoedsoupe/peri/commit/859255d911c14af795a2d69f9a6d1bded7c30ea2))

## [0.7.0](https://github.com/zoedsoupe/peri/compare/v0.6.2...v0.7.0) (2026-04-27)


### Features

* add :meta wrapper and schema-level meta opts ([#47](https://github.com/zoedsoupe/peri/issues/47)) ([b63584c](https://github.com/zoedsoupe/peri/commit/b63584c6ef61c81521b991210129b175a616afd5))
* add :multi directive for tagged unions ([#51](https://github.com/zoedsoupe/peri/issues/51)) ([4727871](https://github.com/zoedsoupe/peri/commit/47278718d4079977742df9c69f9e7476c9c4be3d))
* add :ref directive for recursive and cross-module schemas ([#50](https://github.com/zoedsoupe/peri/issues/50)) ([b5c778b](https://github.com/zoedsoupe/peri/commit/b5c778bee3bd5d1cb317ff05d6281323bf8a575d))
* add JSON Schema (Draft 7) bidirectional conversion ([#49](https://github.com/zoedsoupe/peri/issues/49)) ([7a78a14](https://github.com/zoedsoupe/peri/commit/7a78a14eda19abe6952e0ec5e852d5002ac78fc5))
* add Peri.walk/2 schema rewriter ([#53](https://github.com/zoedsoupe/peri/issues/53)) ([1464f3f](https://github.com/zoedsoupe/peri/commit/1464f3f77f27a9471f80bd07532db96943dc444c))
* per-field custom error overrides + i18n hook ([#52](https://github.com/zoedsoupe/peri/issues/52)) ([838514c](https://github.com/zoedsoupe/peri/commit/838514cff8c9b074dbfca79cd269d20b48ddb7b7))
* per-field gen: override for StreamData generation ([#54](https://github.com/zoedsoupe/peri/issues/54)) ([029da56](https://github.com/zoedsoupe/peri/commit/029da561cb39f62ae6f9e9a8145e4bb09887706d))

## [0.6.2](https://github.com/zoedsoupe/peri/compare/v0.6.1...v0.6.2) (2025-08-27)

### Bug Fixes

- default appliance on nested partial required schema ([#45](https://github.com/zoedsoupe/peri/issues/45)) ([01a6ca2](https://github.com/zoedsoupe/peri/commit/01a6ca25370f9748fa6cccb271076122387c948e))

### Continuous Integration

- add auto hex publish ([3d7e67a](https://github.com/zoedsoupe/peri/commit/3d7e67a7986cd6cbaaf9df193c75e95564e02548))

## [0.6.1](https://github.com/zoedsoupe/peri/compare/v0.6.0...v0.6.1) (2025-08-14)

### Bug Fixes

- schema with nested required fields ([#41](https://github.com/zoedsoupe/peri/issues/41)) ([69e843a](https://github.com/zoedsoupe/peri/commit/69e843a528524e463bb2e9020eecc1fd39398362))

## [0.6.0](https://github.com/zoedsoupe/peri/compare/v0.5.1...v0.6.0) (2025-07-16)

### Features

- `:schema` validator that can accept additional keys ([#37](https://github.com/zoedsoupe/peri/issues/37)) ([098be96](https://github.com/zoedsoupe/peri/commit/098be96a106671119bc7ea83d6fe9099a2319c36))
- multiple validator options ([#35](https://github.com/zoedsoupe/peri/issues/35)) ([2c5ec2f](https://github.com/zoedsoupe/peri/commit/2c5ec2fccdb90663372f90fe6d21ec9ce9f48133))

## [0.5.1] - 2025-6-29

### Added

- Split out `validation_result` from validation type for reuse (#34)

## [0.5.0] - 2025-06-18

### Added

- **Validation Modes**: New permissive mode allows preserving fields not defined in the schema (#33)
  - Default mode remains `:strict` which filters out undefined fields
  - New `:permissive` mode preserves all input fields while still validating defined fields
  - Support for mode option in `defschema` macro: `defschema :name, schema, mode: :permissive`
  - Useful for API gateways, progressive validation, and middleware scenarios

### Fixed

- Fixed nested schemas in lists not having their keys atomized properly (#32)
  - String keys in nested schemas within lists are now correctly converted to atoms
  - Maintains consistent behavior with top-level schema validation

### Internal

- Added `CLAUDE.md` file for AI-assisted development guidance
- Enhanced `.formatter.exs` to export `defschema/3` for proper formatting

## [0.4.1] - 2025-06-18

### Changed

- **BREAKING**: Minimum Elixir version requirement is now 1.17 due to `Duration` struct usage introduced in 0.4.0
  - The `Duration` struct was introduced in Elixir 1.17
  - Previous `mix.exs` incorrectly specified `~> 1.16` compatibility

## [0.4.0] - 2025-10-06 [YANKED]

### Added

- **Ecto Integration**: New `Peri.to_changeset!/2` function to generate Ecto changesets from Peri schemas
  - Automatically generated `<name>_changeset/1` functions when defining schemas with `defschema` (when Ecto is loaded)
  - Support for all Peri types in Ecto changesets including nested schemas, custom types, and validations
  - Custom Ecto types: `Peri.Ecto.Type.PID`, `Peri.Ecto.Type.Atom`, `Peri.Ecto.Type.Any`, `Peri.Ecto.Type.Tuple`, `Peri.Ecto.Type.Either`, `Peri.Ecto.Type.OneOf`
  - Full support for embedded schemas with `:oneof`, `:either`, and nested map validations
  - Comprehensive validation rules are preserved when converting to changesets

- **New Types**:
  - `:duration` type for validating `%Duration{}` structs
- **JSON Support**:
  - Added `Jason.Encoder` protocol implementation for `Peri.Error`
  - Support for encoding errors as JSON when Jason is available
- **Performance Benchmarks**:
  - Added benchmark suite comparing Peri validation with Ecto changeset generation
  - Benchmarks for both simple and complex schemas

### Changed

- Updated Elixir version requirement in development environment to 1.19.0-rc.0
- Updated nix flake configuration with elixir-overlay
- Improved error handling and JSON encoding for `Peri.Error`

### Internal

- Major refactoring of the core `Peri` module to support Ecto integration
- Added `Peri.Ecto` module for parsing Peri schemas into Ecto-compatible definitions
- Enhanced type system to support bidirectional conversion between Peri and Ecto types

## [0.3.3] - 2025-06-10

### Added

- Support for 2-arity callbacks in `:cond` and `:dependent` types (#28)
  - 1-arity callbacks receive the root data structure (backward compatible)
  - 2-arity callbacks receive `(current, root)` where:
    - `current` is the data at the current validation context (e.g., list element being validated)
    - `root` is the entire root data structure
  - This is especially useful when validating elements within lists, allowing callbacks to access the current element's data instead of the parent structure
  - MFA (Module, Function, Arguments) style callbacks also support 2-arity functions

## [0.3.1] - 2025-03-14

### Fixed

- Make `:either` behave consistently with `:oneof` for nested schemas (#21)

### Added

- New schema types for map and literal (#22)

## [0.2.11] - 2024-09-16

### Added

- ability to pass partial MFA (aka `{mod, fun}`) or complete MFA (aka `{mof, fun, args}`) to `:transform`, `:dependent` and `:default` directives

## [0.2.10] - 2024-09-16

### Added

- fixes for `0.2.10` [45300d3]
  - default values are also applied to nested schemas when the parent node is `nil`
  - all type schemas are treat as optional by default
  - allow types as valid schema definition
    - `:date`
    - `:time`
    - `:datetime`
    - `:naive_datetime`
    - `:pid`

## [0.2.8] - 2024-08-01

### Added

- handle structs as input data for schemas [859a0fd]
- support validate enumerable schemas on raw data structures (eg. `:list` type) [32aa540]

## [0.2.7] - 2024-07-28

### Added

- Support multiple dependencies for the `:dependent` type [1be99ef]
- `:cond` type receives "root data" and is treated as required by default [336316c]
- basic `Jason.Protocol` for `Peri.Error` (optional) [9031b1e]
- correctly pass "root data" to `:cond` and `:dependent` types [b79dfbd]
- allow usage of `:one_of` and `get_schema/1` [cb1b250]
- handle schemas definitions with string keys [266b5a2]

## [0.2.6] - 2024-06-27

### Added

- Data generation with based on `StreamData` provided as the `Peri.generate/1` function that receives a schema and returns a stream of generated data that matches this schema. [c85b972]

## [0.2.5] - 2024-06-22

### Added

- Numeric and String Validations: Implemented new validation types for numeric and string data, including regex patterns, equality, inequality, range, and length validations. This allows for more granular and specific data validations. [9bb797e]

## [0.2.4] - 2024-06-21

- Implemented new type `{type, {:default, default}}`. [a569ecf, 821935f]
- Implemented new type `{type, {:transform, mapper}}`. [785179d]

## [0.2.3] - 2024-06-18

### Added

- Implemented schema validation, bang functions, and improved error inspection. [fc061f0]

### Fixed

- Improved error handling and inspecting. [f4d504b, afb054e]

## [0.2.2] - 2024-06-17

### Added

- Native support for keyword lists. [9f8aaef]
- `conforms?/1` function. [9a39ed8]

## [0.2.1] - 2024-06-16

### Added

- Continuous Integration (CI) setup. [16cf116]

### Fixed

- Corrected mix.exs file for hex package. [af5a744]

## [0.2.0] - 2024-06-15

### Added

- Enhanced error handling features. [f4d504b, afb054e]

### Fixed

- Documentation updates in README and Hex docs. [4fd48ce]

## [0.1.4] - 2024-06-10

### Added

- Support for `any`, `atom`, `oneof`, and `either` types. [6a225f4]

## [0.1.2] - 2024-06-05

### Added

- Removed unknown fields from schema validation. [3fa79d4]
- Allowed custom, composable, and recursive schemas. [fd1f593]

### Fixed

- Support for string map keys. [1b6edef]

## [0.1.1] - 2024-06-02

### Added

- Support for `tuple`, `lists`, `enum`, and custom types. [7766adc]

## [0.1.0] - 2024-06-01

### Added

- Initial version of Peri with basic schema validation functionalities. [7044ea7]

[0.5.0]: https://github.com/zoedsoupe/peri/compare/v0.4.1...v0.5.0
[0.4.1]: https://github.com/zoedsoupe/peri/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/zoedsoupe/peri/compare/v0.3.3...v0.4.0
[0.3.3]: https://github.com/zoedsoupe/peri/compare/v0.3.1...v0.3.3
[0.3.1]: https://github.com/zoedsoupe/peri/compare/v0.2.11...v0.3.1
[0.2.11]: https://github.com/zoedsoupe/peri/compare/v0.2.10...v0.2.11
[0.2.10]: https://github.com/zoedsoupe/peri/compare/v0.2.8...v0.2.10
[0.2.8]: https://github.com/zoedsoupe/peri/compare/v0.2.7...v0.2.8
[0.2.7]: https://github.com/zoedsoupe/peri/compare/v0.2.6...v0.2.7
[0.2.6]: https://github.com/zoedsoupe/peri/compare/v0.2.5...v0.2.6
[0.2.5]: https://github.com/zoedsoupe/peri/compare/v0.2.4...v0.2.5
[0.2.4]: https://github.com/zoedsoupe/peri/compare/v0.2.3...v0.2.4
[0.2.3]: https://github.com/zoedsoupe/peri/compare/v0.2.2...v0.2.3
[0.2.2]: https://github.com/zoedsoupe/peri/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/zoedsoupe/peri/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/zoedsoupe/peri/compare/v0.1.4...v0.2.0
[0.1.4]: https://github.com/zoedsoupe/peri/compare/v0.1.2...v0.1.4
[0.1.2]: https://github.com/zoedsoupe/peri/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/zoedsoupe/peri/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/zoedsoupe/peri/releases/tag/v0.1.0
