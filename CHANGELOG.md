# Changelog

## [0.9.0](https://github.com/streamixs/cluster/compare/v0.8.0...v0.9.0) (2026-11-28)


### Features

* **argocd:** add Pocket-ID OIDC and RBAC ([#239](https://github.com/streamixs/cluster/issues/239)) ([4c48a91](https://github.com/streamixs/cluster/commit/4c48a913a39a92475b41e96ada3832d8c4cd8860))
* **argocd:** restrict platform AppProject scope ([#238](https://github.com/streamixs/cluster/issues/238)) ([380d24b](https://github.com/streamixs/cluster/commit/380d24b3b6c8a1a1946ee55b4f16b5b53cf2ad95))
* **monitoring:** add actionable alert rules ([#245](https://github.com/streamixs/cluster/issues/245)) ([8408dec](https://github.com/streamixs/cluster/commit/8408deca22b3e2e1f75d6d5f599dd340555bbcaf))
* **monitoring:** enable Telegram alerting and secure Grafana admin ([#234](https://github.com/streamixs/cluster/issues/234)) ([9114367](https://github.com/streamixs/cluster/commit/91143675f1164932b1ac55c17b4f6155eeaebd79))
* **monitoring:** scrape cert-manager, Longhorn and CNPG ([#242](https://github.com/streamixs/cluster/issues/242)) ([692d3d5](https://github.com/streamixs/cluster/commit/692d3d52c18ccf177837525873965f874705b82c))
* **network:** isolate argocd/auth and enforce PSS ([#247](https://github.com/streamixs/cluster/issues/247)) ([72ed42a](https://github.com/streamixs/cluster/commit/72ed42ae38239c0459478264dadca49f544902cb))


### Bug Fixes

* **argocd:** unblock monitoring manifest generation ([#249](https://github.com/streamixs/cluster/issues/249)) ([c417b91](https://github.com/streamixs/cluster/commit/c417b91dd0055b9398dd6ca7939a3c4011fe4177))
* **auth:** use 32-char oauth2-proxy cookie secret ([#226](https://github.com/streamixs/cluster/issues/226)) ([0e0934c](https://github.com/streamixs/cluster/commit/0e0934cf460e50b8cb2b0c2c5c62ccfadc3fa2a2))
* **auth:** use oauth2-proxy root endpoint for forward-auth ([#227](https://github.com/streamixs/cluster/issues/227)) ([d57e719](https://github.com/streamixs/cluster/commit/d57e71969abb6cc980649a55675e77d1127cf379))
* **auth:** use plural cookie domains for oauth2-proxy ([#228](https://github.com/streamixs/cluster/issues/228)) ([46822b4](https://github.com/streamixs/cluster/commit/46822b44370fd1f0055e6583a2dd89ce3e26ee92))
* **ci:** retry and checksum-verify CI tool downloads ([#217](https://github.com/streamixs/cluster/issues/217)) ([7c467b9](https://github.com/streamixs/cluster/commit/7c467b9ec3a4ee26d6d14b3c824530c1b9a9f14c))
* **monitoring:** drop Grafana rollingUpdate for Recreate ([#236](https://github.com/streamixs/cluster/issues/236)) ([6e64057](https://github.com/streamixs/cluster/commit/6e64057bce0d2c682ee6197296d8fd8046dbfa41))
* **monitoring:** route InfoInhibitor to null ([#248](https://github.com/streamixs/cluster/issues/248)) ([4b85590](https://github.com/streamixs/cluster/commit/4b8559019b249c59f8dfc57eeb2ac65b315e7af1))
* **monitoring:** unblock Grafana rollout and use public alert URLs ([#235](https://github.com/streamixs/cluster/issues/235)) ([e0faec3](https://github.com/streamixs/cluster/commit/e0faec33cf279962c0532fc6b4930d1119c689a6))

## [0.8.0](https://github.com/streamixs/cluster/compare/v0.7.0...v0.8.0) (2026-10-21)


### Features

* **hermes:** improve hermes access ([#189](https://github.com/streamixs/cluster/issues/189)) ([411fd35](https://github.com/streamixs/cluster/commit/411fd35f3a75c9e637204a6ee047610f287d287d))
* **plex:** add igpu integration intel ([#194](https://github.com/streamixs/cluster/issues/194)) ([4f0faf6](https://github.com/streamixs/cluster/commit/4f0faf688d2a36b3c5be328158087421bd662810))


### Bug Fixes

* **docs:** corriger l'IP de TrueNAS (192.168.1.10) ([#186](https://github.com/streamixs/cluster/issues/186)) ([381fe40](https://github.com/streamixs/cluster/commit/381fe4011d763d44ddc8a6fb96b83f533d85a177))
* **loki:** remove gateway from loki and fix endpoint ([#191](https://github.com/streamixs/cluster/issues/191)) ([441a0b3](https://github.com/streamixs/cluster/commit/441a0b336121f061596e411fbce2348cdd8c1712))
* **traefik:** add policy for traefik ([#193](https://github.com/streamixs/cluster/issues/193)) ([29b3feb](https://github.com/streamixs/cluster/commit/29b3feb68a49707b99aa18d0778635a6bb06252d))
* **traefik:** add second instance and do not deploy on same worker and fix ip ([#192](https://github.com/streamixs/cluster/issues/192)) ([d4f65ef](https://github.com/streamixs/cluster/commit/d4f65efd7c3dfbe347d93e34e3afe39ad7506928))

## [0.7.0](https://github.com/streamixs/cluster/compare/v0.6.1...v0.7.0) (2026-09-22)


### Features

* **hermes:** deployer l'agent Hermes avec gateway Telegram ([#173](https://github.com/streamixs/cluster/issues/173)) ([4556555](https://github.com/streamixs/cluster/commit/45565555e4f0d4e8ede2a2019f2ec787b61afaad))
* **hermes:** exposer le dashboard sur hermes.streamixs.com via Pocket-ID ([#177](https://github.com/streamixs/cluster/issues/177)) ([87078be](https://github.com/streamixs/cluster/commit/87078bece5fe7a6d4992ccd8b1c749c3fac620da))
* **securo:** deployer Securo, gestionnaire de finances auto-heberge ([e477cde](https://github.com/streamixs/cluster/commit/e477cde2acfb198706319af1b11333aae69da1d9))
* **securo:** deployer Securo, gestionnaire de finances auto-heberge ([#154](https://github.com/streamixs/cluster/issues/154)) ([e477cde](https://github.com/streamixs/cluster/commit/e477cde2acfb198706319af1b11333aae69da1d9))


### Bug Fixes

* **argocd:** permettre de figer l'auto-sync de securo ([#158](https://github.com/streamixs/cluster/issues/158)) ([4409c48](https://github.com/streamixs/cluster/commit/4409c483f2cc8acdf1a5e7f80defc4622eeaed6b))
* **hermes:** activer le plugin telegram via un managed scope ([#174](https://github.com/streamixs/cluster/issues/174)) ([673e64d](https://github.com/streamixs/cluster/commit/673e64d60c4973bf08246b4afe5fd8fb21875626))
* **hermes:** declarer la VM Ollama comme provider custom ([#175](https://github.com/streamixs/cluster/issues/175)) ([ac671a4](https://github.com/streamixs/cluster/commit/ac671a47c0c8925815f6f40d4784f0800f08b395))
* **hermes:** une seule authentification sur le dashboard ([#178](https://github.com/streamixs/cluster/issues/178)) ([4116f20](https://github.com/streamixs/cluster/commit/4116f20e5d070a115d3c8e34d7fb04d4a582f241))

## [0.6.1](https://github.com/streamixs/cluster/compare/v0.6.0...v0.6.1) (2026-08-18)


### Bug Fixes

* **deps:** epingler argo-rollouts et couvrir les dependances non suivies ([#148](https://github.com/streamixs/cluster/issues/148)) ([36e2024](https://github.com/streamixs/cluster/commit/36e2024efcf49c478d6ddf4e9655dbf562c3a9e4))

## [0.6.0](https://github.com/streamixs/cluster/compare/v0.5.0...v0.6.0) (2026-08-18)


### Features

* **cilium:** palier 1 - passer de 1.17.1 a 1.18.12 ([#143](https://github.com/streamixs/cluster/issues/143)) ([a943585](https://github.com/streamixs/cluster/commit/a943585e916e326ceaa7c9d255c50423f033b73b))
* **cilium:** palier 2 - passer de 1.18.12 a 1.19.6 ([#146](https://github.com/streamixs/cluster/issues/146)) ([5277228](https://github.com/streamixs/cluster/commit/5277228504c21cdabad0ea7b785d26ab0f720e6b))
* **cilium:** palier 3 - passer de 1.19.6 a 1.20.1 ([#147](https://github.com/streamixs/cluster/issues/147)) ([7b32c8e](https://github.com/streamixs/cluster/commit/7b32c8e0735edf52a92da51eaceeebf1ad6f5532))

## [0.5.0](https://github.com/streamixs/cluster/compare/v0.4.0...v0.5.0) (2026-08-09)


### Features

* **media:** deployer autobrr pour l'automatisation des annonces IRC ([#137](https://github.com/streamixs/cluster/issues/137)) ([3937386](https://github.com/streamixs/cluster/commit/393738632ae858bf2acccb67f1ce9bccff04f4ce))


### Bug Fixes

* **media:** durcir la resilience de qbittorrent et qbittorrent-seed ([#134](https://github.com/streamixs/cluster/issues/134)) ([e6be0c4](https://github.com/streamixs/cluster/commit/e6be0c4f922cde40360f631863bfc862ebfa5156))

## [0.4.0](https://github.com/streamixs/cluster/compare/v0.3.1...v0.4.0) (2026-05-20)


### Features

* **ci:** kustomize build + kubeconform validation par app ([#102](https://github.com/streamixs/cluster/issues/102)) ([19e2b1e](https://github.com/streamixs/cluster/commit/19e2b1e052ef4ae418bc28e5cc2d95907571950b))

## [0.3.1](https://github.com/streamixs/cluster/compare/v0.3.0...v0.3.1) (2026-05-20)


### Bug Fixes

* **gitops:** back on version of traefik-forward-auth ([#100](https://github.com/streamixs/cluster/issues/100)) ([3097e2a](https://github.com/streamixs/cluster/commit/3097e2af536610327ba198bbce136bca2535a6c6))

## [0.3.0](https://github.com/streamixs/cluster/compare/v0.2.0...v0.3.0) (2026-05-19)


### Features

* **ci:** trunk-based workflow + release-please automation ([#98](https://github.com/streamixs/cluster/issues/98)) ([2fb142b](https://github.com/streamixs/cluster/commit/2fb142b03a86a4a6786a5b2c9c785d67a9d01b9a))
