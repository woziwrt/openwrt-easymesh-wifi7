# Our patches

Every patch this project applies to code it did not write, generated from the patch headers
(`From:` and `Subject:`). Patches by other authors are marked; they are carried here because they are not
in the trees we build from yet. The files are the source of truth - each one says why it exists.

| Where | Patches |
|---|---|
| [Wi-Fi: hostapd, wpa_supplicant, mac80211, mt76](#wi-fi-hostapd-wpa_supplicant-mac80211-mt76) | 16 |
| [iopsys ieee1905](#iopsys-ieee1905) | 12 |
| [iopsys map-controller](#iopsys-map-controller) | 90 |
| [iopsys map-agent](#iopsys-map-agent) | 75 |
| [iopsys libwifi](#iopsys-libwifi) | 23 |
| [iopsys wifimngr](#iopsys-wifimngr) | 2 |
| [Kernel, U-Boot and board support](#kernel-u-boot-and-board-support) | 11 |
| [LuCI](#luci) | 1 |
| **Total** | **230** |

## Wi-Fi: hostapd, wpa_supplicant, mac80211, mt76

Applied on top of the MediaTek OpenWrt feed.

| Patch | What it does |
|---|---|
| [`0118-cp-mtk-mt76-mt7996-Update-wcid-idx-when-sending-null-fu.patch`](../patches/wifi/0118-cp-mtk-mt76-mt7996-Update-wcid-idx-when-sending-null-fu.patch) | mtk: mt76: mt7996: Update wcid idx when sending null func *(by Peter Chiu)* |
| [`0264-wpa_s-add-btwt-join-command.patch`](../patches/wifi/0264-wpa_s-add-btwt-join-command.patch) | wpa_supplicant: add JOIN_BTWT command for broadcast TWT membership |
| [`0266-mld-find-sta-pending-assoc.patch`](../patches/wifi/0266-mld-find-sta-pending-assoc.patch) | AP MLD: find a station that has been answered but not yet acked |
| [`0267-mld-link-aid-offset.patch`](../patches/wifi/0267-mld-link-aid-offset.patch) | AP MLD: mark the link AID with the same offset it was allocated with |
| [`0268-mld-link-free-keeps-aid.patch`](../patches/wifi/0268-mld-link-free-keeps-aid.patch) | AP MLD: one AID bit per sta_info, and a peer interface that belongs to the station |
| [`0269-ttlm-ctrl-iface-parser-fixes.patch`](../patches/wifi/0269-ttlm-ctrl-iface-parser-fixes.patch) | hostapd: fix three bugs in the Neg-TTLM ctrl_iface parser |
| [`0270-wpa_supplicant-apsta-keep-aps-on-mesh-node.patch`](../patches/wifi/0270-wpa_supplicant-apsta-keep-aps-on-mesh-node.patch) | wpa_supplicant.uc: apsta must not stop the APs of a mesh node |
| [`0271-hostapd-restart-mld-sibling-radios.patch`](../patches/wifi/0271-hostapd-restart-mld-sibling-radios.patch) | hostapd.uc: restart every radio of an MLD when one of them restarts |
| [`0272-ctrl-iface-replies-must-not-block.patch`](../patches/wifi/0272-ctrl-iface-replies-must-not-block.patch) | hostapd: ctrl_iface replies must not block |
| [`0273-neg-ttlm-request-element-length.patch`](../patches/wifi/0273-neg-ttlm-request-element-length.patch) | hostapd: size the Neg-TTLM request element for 1-octet link maps |
| [`0274-neg-ttlm-keep-dialog-token-across-parse.patch`](../patches/wifi/0274-neg-ttlm-keep-dialog-token-across-parse.patch) | hostapd: keep the Neg-TTLM dialog token across parsing the request |
| [`0275-neg-ttlm-request-no-uninitialised-pointers.patch`](../patches/wifi/0275-neg-ttlm-request-no-uninitialised-pointers.patch) | hostapd: Neg-TTLM request - no uninitialised pointers, no clobbered map |
| [`0277-apsta-close-backhaul-bss-keep-fronthaul.patch`](../patches/wifi/0277-apsta-close-backhaul-bss-keep-fronthaul.patch) | apsta: close the backhaul BSS at once, keep the fronthaul 20 s |
| [`999-fix-01-mac80211-btwt-ap-mode.patch`](../patches/wifi/999-fix-01-mac80211-btwt-ap-mode.patch) | mac80211: allow BTWT membership join in AP mode regardless of he_btwt_supported |
| [`999-wifi-01-mt7996-per-band-leds.patch`](../patches/wifi/999-wifi-01-mt7996-per-band-leds.patch) | wifi: mt76: mt7996: register a LED classdev for every band |
| [`999-wifi-02-mt76-share-tpt-led-trigger.patch`](../patches/wifi/999-wifi-02-mt76-share-tpt-led-trigger.patch) | wifi: mt76: share the throughput LED trigger across all bands |

## iopsys ieee1905

The IEEE 1905 transport: topology, CMDU delivery, relaying.

| Patch | What it does |
|---|---|
| [`0001-ieee1905-skip-slow-wifi-dm-probes.patch`](../iopsys/overlay/ieee1905/patches/0001-ieee1905-skip-slow-wifi-dm-probes.patch) | ieee1905: ieee1905 skip slow wifi dm probes |
| [`0002-mld-phase3-ttlm-tlv-easymesh-header.patch`](../iopsys/overlay/ieee1905/patches/0002-mld-phase3-ttlm-tlv-easymesh-header.patch) | ieee1905: mld phase3 ttlm tlv easymesh header |
| [`0003-ieee1905-skip-probe-backhaul-bsta.patch`](../iopsys/overlay/ieee1905/patches/0003-ieee1905-skip-probe-backhaul-bsta.patch) | ieee1905: ieee1905 skip probe backhaul bsta |
| [`0004-ieee1905-map-idempotent-register.patch`](../iopsys/overlay/ieee1905/patches/0004-ieee1905-map-idempotent-register.patch) | ieee1905: ieee1905 map idempotent register |
| [`0005-prefer-direct-neighbour-for-cmdu-sender.patch`](../iopsys/overlay/ieee1905/patches/0005-prefer-direct-neighbour-for-cmdu-sender.patch) | ieee1905: prefer direct neighbours when stamping a CMDU sender |
| [`0006-bridge-fallback-for-unaddressable-unicast.patch`](../iopsys/overlay/ieee1905/patches/0006-bridge-fallback-for-unaddressable-unicast.patch) | ieee1905 0006: let the bridge deliver a unicast we cannot address |
| [`0007-mld-interfaces-report-11be-not-unknown-media.patch`](../iopsys/overlay/ieee1905/patches/0007-mld-interfaces-report-11be-not-unknown-media.patch) | ieee1905 0007: an MLD interface knows its media type by name |
| [`0009-guard-null-mediainfo-in-linkmetrics.patch`](../iopsys/overlay/ieee1905/patches/0009-guard-null-mediainfo-in-linkmetrics.patch) | ieee1905 0009: do not dereference a NULL mediainfo for MLD interfaces |
| [`0010-retract-get-station-hang-claim.patch`](../iopsys/overlay/ieee1905/patches/0010-retract-get-station-hang-claim.patch) | ieee1905: retract the never-measured GET_STATION hang claim from the skip-probe comment |
| [`0011-steering-policy-nine-bytes-and-chirp-bounds.patch`](../iopsys/overlay/ieee1905/patches/0011-steering-policy-nine-bytes-and-chirp-bounds.patch) | ieee1905: Steering Policy is nine bytes per radio, and chirp reads inside the TLV |
| [`0012-unicast-cmdu-to-non-adjacent-al.patch`](../iopsys/overlay/ieee1905/patches/0012-unicast-cmdu-to-non-adjacent-al.patch) | ieee1905: send unicast CMDUs to non-adjacent AL addresses |
| [`0013-relay-dedup-per-origin.patch`](../iopsys/overlay/ieee1905/patches/0013-relay-dedup-per-origin.patch) | relay: key the multicast duplicate check on {origin, MID}, not MID alone |

## iopsys map-controller

The EasyMesh controller.

| Patch | What it does |
|---|---|
| [`900-add-mapdb-sqlite-persistence.patch`](../iopsys/overlay/map-controller/patches/900-add-mapdb-sqlite-persistence.patch) | map-controller: add mapdb sqlite persistence |
| [`920-phase1-write-hooks.patch`](../iopsys/overlay/map-controller/patches/920-phase1-write-hooks.patch) | map-controller: phase1 write hooks |
| [`930-phase2-recovery.patch`](../iopsys/overlay/map-controller/patches/930-phase2-recovery.patch) | map-controller: phase2 recovery |
| [`940-controller-startup-retry.patch`](../iopsys/overlay/map-controller/patches/940-controller-startup-retry.patch) | map-controller: controller startup retry |
| [`950-mld-phase1-apmld-parse.patch`](../iopsys/overlay/map-controller/patches/950-mld-phase1-apmld-parse.patch) | map-controller: mld phase1 apmld parse |
| [`951-mld-phase2-security-parse.patch`](../iopsys/overlay/map-controller/patches/951-mld-phase2-security-parse.patch) | map-controller: mld phase2 security parse |
| [`952-mld-phase3-ttlm-controller.patch`](../iopsys/overlay/map-controller/patches/952-mld-phase3-ttlm-controller.patch) | map-controller: mld phase3 ttlm controller |
| [`960-fix-nodedup-mld-recovery.patch`](../iopsys/overlay/map-controller/patches/960-fix-nodedup-mld-recovery.patch) | map-controller: fix nodedup mld recovery |
| [`961-fix-radio-reconcile-sweep.patch`](../iopsys/overlay/map-controller/patches/961-fix-radio-reconcile-sweep.patch) | map-controller: fix radio reconcile sweep |
| [`962-tripwire-node-without-policy.patch`](../iopsys/overlay/map-controller/patches/962-tripwire-node-without-policy.patch) | map-controller: tripwire node without policy |
| [`963-clean-node-respect-shared-identity.patch`](../iopsys/overlay/map-controller/patches/963-clean-node-respect-shared-identity.patch) | map-controller: clean node respect shared identity |
| [`964-node-identity-invariants.patch`](../iopsys/overlay/map-controller/patches/964-node-identity-invariants.patch) | map-controller: node identity invariants |
| [`965-radio-follows-the-box.patch`](../iopsys/overlay/map-controller/patches/965-radio-follows-the-box.patch) | map-controller: a radio follows the box, not the address |
| [`970-fix-bss-ruid-foreign-key.patch`](../iopsys/overlay/map-controller/patches/970-fix-bss-ruid-foreign-key.patch) | map-controller: give a BSS the RUID of its radio |
| [`971-fill-agent-depth-from-topology.patch`](../iopsys/overlay/map-controller/patches/971-fill-agent-depth-from-topology.patch) | map-controller: take agent depth from the topology tree |
| [`973-agent-backhaul-view.patch`](../iopsys/overlay/map-controller/patches/973-agent-backhaul-view.patch) | map-controller: derive an agent backhaul view instead of storing it |
| [`9731-agent-backhaul-band-behind-agents.patch`](../iopsys/overlay/map-controller/patches/9731-agent-backhaul-band-behind-agents.patch) | map-controller: resolve the backhaul band for agents behind agents |
| [`974-bss-reconcile-sweep.patch`](../iopsys/overlay/map-controller/patches/974-bss-reconcile-sweep.patch) | map-controller: reconcile the bss table instead of only growing it |
| [`975-backhaul-mld-bstamld-chain.patch`](../iopsys/overlay/map-controller/patches/975-backhaul-mld-bstamld-chain.patch) | map-controller: persist the backhaul MLD (bstamld chain) |
| [`976-notif-accept-apmld-mac.patch`](../iopsys/overlay/map-controller/patches/976-notif-accept-apmld-mac.patch) | map-controller: 976 - accept AP-MLD MAC BSSID in the Client |
| [`977-phase1-sta-persistence.patch`](../iopsys/overlay/map-controller/patches/977-phase1-sta-persistence.patch) | map-controller: 977 - persist associated clients to sta table |
| [`986-report-unsent-cmdu-as-failure.patch`](../iopsys/overlay/map-controller/patches/986-report-unsent-cmdu-as-failure.patch) | map-controller 986: a CMDU that was never sent must not report success |
| [`987-report-rejected-cmdu-as-failure.patch`](../iopsys/overlay/map-controller/patches/987-report-rejected-cmdu-as-failure.patch) | map-controller 987: a CMDU that ieee1905d refused must say so |
| [`988-topology-rebuild-gate-agents-only.patch`](../iopsys/overlay/map-controller/patches/988-topology-rebuild-gate-agents-only.patch) | map-controller: 988 - fire topology rebuild on agent count |
| [`989-reconcile-sweep-stale-bss-sta.patch`](../iopsys/overlay/map-controller/patches/989-reconcile-sweep-stale-bss-sta.patch) | map-controller: 989 - reconcile-sweep stale bss and sta rows |
| [`990-topology-tree-from-assoc-upstream.patch`](../iopsys/overlay/map-controller/patches/990-topology-tree-from-assoc-upstream.patch) | map-controller: 990 - build backhaul tree from assoc/upstream |
| [`992-topology-response-use-assoc-build.patch`](../iopsys/overlay/map-controller/patches/992-topology-response-use-assoc-build.patch) | map-controller: 992 - build topology from assoc on Topology Response |
| [`993-sta-sweep-backhaul-only.patch`](../iopsys/overlay/map-controller/patches/993-sta-sweep-backhaul-only.patch) | map-controller: 993 - sta sweep only removes bSTA ghosts |
| [`994-keep-last-good-agent-depth.patch`](../iopsys/overlay/map-controller/patches/994-keep-last-good-agent-depth.patch) | map-controller: 994 - keep last-good agent.depth |
| [`995-topology-resolve-mlo-parent-by-mld-addr.patch`](../iopsys/overlay/map-controller/patches/995-topology-resolve-mlo-parent-by-mld-addr.patch) | map-controller: 995 - resolve an MLO uplink by AP-MLD address |
| [`996-uplink-from-bsta-mld-report.patch`](../iopsys/overlay/map-controller/patches/996-uplink-from-bsta-mld-report.patch) | map-controller 996: take the uplink from what the agent reports |
| [`997-read-uplink-from-topology-response.patch`](../iopsys/overlay/map-controller/patches/997-read-uplink-from-topology-response.patch) | map-controller 997: the uplink is in the Topology Response too - read it |
| [`9992-guard-null-radio-el.patch`](../iopsys/overlay/map-controller/patches/9992-guard-null-radio-el.patch) | map-controller 9992: do not dereference a radio that was never filled |
| [`9993-node-expiry-margin.patch`](../iopsys/overlay/map-controller/patches/9993-node-expiry-margin.patch) | map-controller 9993: give node liveness a margin worth the name |
| [`9994-send-tid-to-link-policy.patch`](../iopsys/overlay/map-controller/patches/9994-send-tid-to-link-policy.patch) | map-controller 9994: send a TID-to-Link Mapping policy |
| [`9995-trigger-on-ttlm-policy-change.patch`](../iopsys/overlay/map-controller/patches/9995-trigger-on-ttlm-policy-change.patch) | map-controller 9995: give the TTLM policy file a trigger |
| [`9996-zero-ap-mld-config-tlv.patch`](../iopsys/overlay/map-controller/patches/9996-zero-ap-mld-config-tlv.patch) | map-controller 9996: stop putting uninitialised memory in the AP MLD Config TLV |
| [`9997-ingest-associated-sta-mld-config.patch`](../iopsys/overlay/map-controller/patches/9997-ingest-associated-sta-mld-config.patch) | map-controller 9997: ingest the Associated STA MLD Configuration TLV |
| [`9999-stamld-owner-and-last-seen.patch`](../iopsys/overlay/map-controller/patches/9999-stamld-owner-and-last-seen.patch) | mapc: attribute a STA-MLD to the AP-MLD reporting it |
| [`99991-steer-honour-explicit-source-bss.patch`](../iopsys/overlay/map-controller/patches/99991-steer-honour-explicit-source-bss.patch) | map-controller 99991: steer from the BSS the caller named, not the one we remember |
| [`99992-topology-response-trust-device-info.patch`](../iopsys/overlay/map-controller/patches/99992-topology-response-trust-device-info.patch) | map-controller 99992: trust the Device Information TLV, not the frame source |
| [`99993-keep-measured-rcpi.patch`](../iopsys/overlay/map-controller/patches/99993-keep-measured-rcpi.patch) | map-controller 99993: do not let an unmeasured link erase a measured rcpi |
| [`99994-persist-under-the-node-the-tlv-named.patch`](../iopsys/overlay/map-controller/patches/99994-persist-under-the-node-the-tlv-named.patch) | map-controller 99994: persist under the node the TLV named, not the relay |
| [`99995-mld-leg-follows-its-client.patch`](../iopsys/overlay/map-controller/patches/99995-mld-leg-follows-its-client.patch) | map-controller 99995: let an MLD leg follow its client when it roams |
| [`99996-mld-leg-keeps-its-metrics.patch`](../iopsys/overlay/map-controller/patches/99996-mld-leg-keeps-its-metrics.patch) | map-controller 99996: give an MLD leg somewhere to keep its metrics |
| [`99997-a-leg-has-no-struct-sta.patch`](../iopsys/overlay/map-controller/patches/99997-a-leg-has-no-struct-sta.patch) | map-controller 99997: a leg has no struct sta, so stop requiring one |
| [`99998-write-to-every-copy-of-the-leg.patch`](../iopsys/overlay/map-controller/patches/99998-write-to-every-copy-of-the-leg.patch) | map-controller 99998: write the measurement to every copy of the leg |
| [`99999-keep-the-measurement-outside-the-model.patch`](../iopsys/overlay/map-controller/patches/99999-keep-the-measurement-outside-the-model.patch) | map-controller 99999: keep the measurement outside the model that is torn down |
| [`999991-stamld-on-a-backhaul-bss.patch`](../iopsys/overlay/map-controller/patches/999991-stamld-on-a-backhaul-bss.patch) | map-controller: a STA-MLD on a backhaul BSS is a backhaul |
| [`999992-departed-client-is-not-associated.patch`](../iopsys/overlay/map-controller/patches/999992-departed-client-is-not-associated.patch) | map-controller: stop claiming a departed client is associated |
| [`999993-btm-report-speaks-links-bookkeeping-mlds.patch`](../iopsys/overlay/map-controller/patches/999993-btm-report-speaks-links-bookkeeping-mlds.patch) | map-controller: a BTM report speaks in links, steering bookkeeping in MLDs |
| [`999994-free-the-stamld-children-with-the-model.patch`](../iopsys/overlay/map-controller/patches/999994-free-the-stamld-children-with-the-model.patch) | map-controller: free the STA-MLD children with the AP-MLD model |
| [`999995-db-policy-schema-v3.patch`](../iopsys/overlay/map-controller/patches/999995-db-policy-schema-v3.patch) | mapdb: schema v3 - row timestamps and a signal-history table |
| [`999996-db-policy-write-path.patch`](../iopsys/overlay/map-controller/patches/999996-db-policy-write-path.patch) | mapc_sync: stamp rows on every upsert and sample the signal history |
| [`999997-db-policy-departures-and-ageout.patch`](../iopsys/overlay/map-controller/patches/999997-db-policy-departures-and-ageout.patch) | mapc: uniform departures and an hourly DB janitor |
| [`999998-keep-measured-est-thput.patch`](../iopsys/overlay/map-controller/patches/999998-keep-measured-est-thput.patch) | map-controller 999998: do not let an unmeasured link erase a measured throughput estimate |
| [`999999-relay-blind-handlers-name-the-author.patch`](../iopsys/overlay/map-controller/patches/999999-relay-blind-handlers-name-the-author.patch) | map-controller 999999: every self-attributing handler leaves the author in cmdu->origin |
| [`9999991-departed-node-ageout.patch`](../iopsys/overlay/map-controller/patches/9999991-departed-node-ageout.patch) | map-controller: departed nodes age out of the database like departed clients |
| [`9999992-neighbor-routing-view.patch`](../iopsys/overlay/map-controller/patches/9999992-neighbor-routing-view.patch) | map-controller: write the neighbor routing view (schema table 17 finally gets a writer) |
| [`9999993-remove-dead-tree-walker.patch`](../iopsys/overlay/map-controller/patches/9999993-remove-dead-tree-walker.patch) | map-controller: remove the dead level-order tree walker and stop citing it |
| [`9999994-hist-direction-upsert-guards-null-stamps.patch`](../iopsys/overlay/map-controller/patches/9999994-hist-direction-upsert-guards-null-stamps.patch) | map-controller: hist sample direction, upsert keep-last-good, sta_mld NULL stamps |
| [`9999995-author-attribution-completion.patch`](../iopsys/overlay/map-controller/patches/9999995-author-attribution-completion.patch) | map-controller: author attribution for oper-channel, early-caps and MLD config; steer dst records the MLD |
| [`9999996-bstamld-ask-again-when-the-row-is-missing.patch`](../iopsys/overlay/map-controller/patches/9999996-bstamld-ask-again-when-the-row-is-missing.patch) | Ask again for a backhaul STA-MLD the controller never received |
| [`9999997-ttlm-policy-rides-service-prioritization.patch`](../iopsys/overlay/map-controller/patches/9999997-ttlm-policy-rides-service-prioritization.patch) | info() and not dbg(). On 2026-09-02 the policy was written, its mtime moved |
| [`9999998-wsc-answer-the-agent-that-asked.patch`](../iopsys/overlay/map-controller/patches/9999998-wsc-answer-the-agent-that-asked.patch) | map-controller: answer the agent that asked, not the one that carried the question |
| [`9999999-not-measured-is-not-a-measurement.patch`](../iopsys/overlay/map-controller/patches/9999999-not-measured-is-not-a-measurement.patch) | mapc_sync: not-measured is not a measurement |
| [`99999991-a-bsta-belongs-to-its-radio.patch`](../iopsys/overlay/map-controller/patches/99999991-a-bsta-belongs-to-its-radio.patch) | map-controller: a bSTA record belongs to the radio that names it |
| [`99999992-one-column-one-unit.patch`](../iopsys/overlay/map-controller/patches/99999992-one-column-one-unit.patch) | map-controller: one column, one unit |
| [`99999993-the-report-may-reparent-a-client.patch`](../iopsys/overlay/map-controller/patches/99999993-the-report-may-reparent-a-client.patch) | map-controller: let the periodic report move a client |
| [`99999994-a-count-is-derived-not-carried.patch`](../iopsys/overlay/map-controller/patches/99999994-a-count-is-derived-not-carried.patch) | map-controller: a count is derived, not carried |
| [`99999994-an-unknown-conn-time-is-not-the-newest-one.patch`](../iopsys/overlay/map-controller/patches/99999994-an-unknown-conn-time-is-not-the-newest-one.patch) | map-controller: an unknown conn_time is not the newest one |
| [`99999995-drop-the-policy-binding-before-the-reload-frees-it.patch`](../iopsys/overlay/map-controller/patches/99999995-drop-the-policy-binding-before-the-reload-frees-it.patch) | map-controller: drop the policy binding before the reload frees it |
| [`99999995-initialise-the-list-a-station-hangs-on.patch`](../iopsys/overlay/map-controller/patches/99999995-initialise-the-list-a-station-hangs-on.patch) | map-controller: initialise the list head a station hangs on |
| [`99999996-a-station-belongs-to-one-node.patch`](../iopsys/overlay/map-controller/patches/99999996-a-station-belongs-to-one-node.patch) | map-controller: a station belongs to one node, enforced where it is linked |
| [`99999996-cut-the-children-loose-before-freeing-a-device.patch`](../iopsys/overlay/map-controller/patches/99999996-cut-the-children-loose-before-freeing-a-device.patch) | map-controller: cut the children loose before freeing a device |
| [`99999997-a-name-we-do-not-have-must-not-erase-the-one-we-do.patch`](../iopsys/overlay/map-controller/patches/99999997-a-name-we-do-not-have-must-not-erase-the-one-we-do.patch) | map-controller: a name we do not have must not erase the one we do |
| [`99999997-an-mlo-client-is-somewhere-too.patch`](../iopsys/overlay/map-controller/patches/99999997-an-mlo-client-is-somewhere-too.patch) | map-controller: an MLO client is somewhere too |
| [`99999998-keep-the-tree-over-time-and-the-signal-as-a-series.patch`](../iopsys/overlay/map-controller/patches/99999998-keep-the-tree-over-time-and-the-signal-as-a-series.patch) | map-controller: keep the tree over time, and the signal as a series |
| [`99999999-the-edge-carries-its-signal-and-two-more-series.patch`](../iopsys/overlay/map-controller/patches/99999999-the-edge-carries-its-signal-and-two-more-series.patch) | map-controller: the edge carries its signal, and two more series |
| [`99999999a-take-the-edge-weight-at-the-first-opportunity.patch`](../iopsys/overlay/map-controller/patches/99999999a-take-the-edge-weight-at-the-first-opportunity.patch) | map-controller: take the edge weight at the first opportunity |
| [`99999999b-steer-backhaul-finds-its-target.patch`](../iopsys/overlay/map-controller/patches/99999999b-steer-backhaul-finds-its-target.patch) | map-controller: steer_backhaul finds its target, its bSTA and its channel |
| [`99999999d-topology-one-unplaced-node-does-not-freeze-the-tree.patch`](../iopsys/overlay/map-controller/patches/99999999d-topology-one-unplaced-node-does-not-freeze-the-tree.patch) | map-controller: one unplaced node does not freeze the tree |
| [`99999999e-topology-bounds-and-interface-limit.patch`](../iopsys/overlay/map-controller/patches/99999999e-topology-bounds-and-interface-limit.patch) | topology: bound every TLV walk, keep 32 interfaces, keep |
| [`99999999f-bss-config-report-bits-per-node.patch`](../iopsys/overlay/map-controller/patches/99999999f-bss-config-report-bits-per-node.patch) | map-controller: read the BSS Configuration Report bits the way each node writes them |
| [`99999999g-topology-place-a-node-without-an-uplink-report.patch`](../iopsys/overlay/map-controller/patches/99999999g-topology-place-a-node-without-an-uplink-report.patch) | map-controller: place a node that reports no uplink of its own |
| [`99999999h-controller-capability-tlv-two-octets.patch`](../iopsys/overlay/map-controller/patches/99999999h-controller-capability-tlv-two-octets.patch) | map-controller: send the Controller Capability TLV at two octets |
| [`99999999i-renew-for-a-node-that-never-asked.patch`](../iopsys/overlay/map-controller/patches/99999999i-renew-for-a-node-that-never-asked.patch) | cntlr: offer a renew to a node that has never configured itself |
| [`99999999j-ttlm-policy-first-sighting-is-a-change.patch`](../iopsys/overlay/map-controller/patches/99999999j-ttlm-policy-first-sighting-is-a-change.patch) | map-controller: a policy seen for the first time is a change |
| [`99999999k-learn-bsta-mld-bstas-from-e1.patch`](../iopsys/overlay/map-controller/patches/99999999k-learn-bsta-mld-bstas-from-e1.patch) | map-controller: learn the bSTAs of a bSTA MLD from 0xE1 |
| [`99999999l-radio-carries-channel-utilization.patch`](../iopsys/overlay/map-controller/patches/99999999l-radio-carries-channel-utilization.patch) | map-controller: a radio carries the channel utilization of its BSS |

## iopsys map-agent

The EasyMesh agent on every box.

| Patch | What it does |
|---|---|
| [`0001-register-1905-wireless-backhaul-interface.patch`](../iopsys/overlay/map-agent/patches/0001-register-1905-wireless-backhaul-interface.patch) | map-agent: register 1905 wireless backhaul interface |
| [`0002-register-controller-backhaul-apvlan-1905.patch`](../iopsys/overlay/map-agent/patches/0002-register-controller-backhaul-apvlan-1905.patch) | map-agent: register controller backhaul apvlan 1905 |
| [`0003-mld-phase3-ttlm-agent-emit.patch`](../iopsys/overlay/map-agent/patches/0003-mld-phase3-ttlm-agent-emit.patch) | map-agent: mld phase3 ttlm agent emit |
| [`0005-mapagent-bound-init-onboarding-blocking.patch`](../iopsys/overlay/map-agent/patches/0005-mapagent-bound-init-onboarding-blocking.patch) | map-agent: mapagent bound init onboarding blocking |
| [`970-mapagent-async-refresh.patch`](../iopsys/overlay/map-agent/patches/970-mapagent-async-refresh.patch) | map-agent: make periodic wifi refresh timers asynchronous (onboarding blocker #2, Layer 2) |
| [`976-report-current-uplink.patch`](../iopsys/overlay/map-agent/patches/976-report-current-uplink.patch) | map-agent 976: report the uplink we actually have, not the first one we ever had |
| [`977-serialise-genconfig.patch`](../iopsys/overlay/map-agent/patches/977-serialise-genconfig.patch) | map-agent 977: only one genconfig at a time |
| [`978-teardown-must-not-delete-ap-mld.patch`](../iopsys/overlay/map-agent/patches/978-teardown-must-not-delete-ap-mld.patch) | map-agent 978: tearing down one interface must not delete its whole AP MLD |
| [`979-keep-named-mld-sections.patch`](../iopsys/overlay/map-agent/patches/979-keep-named-mld-sections.patch) | map-agent 979: an AP MLD Config TLV must not rename the local MLD sections |
| [`980-fix-mld-del-affiliated-row-shift-overflow.patch`](../iopsys/overlay/map-agent/patches/980-fix-mld-del-affiliated-row-shift-overflow.patch) | map-agent: fix affiliated-link removal overflowing a 6-byte row |
| [`981-fix-assoc-client-tlv-layout-and-bounds.patch`](../iopsys/overlay/map-agent/patches/981-fix-assoc-client-tlv-layout-and-bounds.patch) | map-agent: keep the Associated Clients TLV self-consistent |
| [`982-fix-agent-status-backhaul-json.patch`](../iopsys/overlay/map-agent/patches/982-fix-agent-status-backhaul-json.patch) | map-agent: emit valid JSON for the backhaul in agent status |
| [`983-keep-last-good-apmld-attribution.patch`](../iopsys/overlay/map-agent/patches/983-keep-last-good-apmld-attribution.patch) | map-agent: never replace a known AP-MLD attribution with nothing |
| [`984-never-pin-backhaul-bssid.patch`](../iopsys/overlay/map-agent/patches/984-never-pin-backhaul-bssid.patch) | map-agent: never pin the backhaul BSSID in config |
| [`985-backhaul-mld-agent-emit.patch`](../iopsys/overlay/map-agent/patches/985-backhaul-mld-agent-emit.patch) | map-agent: backhaul MLD affiliated-link path and TLV emit |
| [`986-fix-mld-fronthaul-client-enum.patch`](../iopsys/overlay/map-agent/patches/986-fix-mld-fronthaul-client-enum.patch) | map-agent: 986 - enumerate MLO fronthaul clients on affiliated APs |
| [`987-mld-clients-from-wifi-ap-mld-master.patch`](../iopsys/overlay/map-agent/patches/987-mld-clients-from-wifi-ap-mld-master.patch) | map-agent: 987 - enumerate MLD clients via wifi.ap.<mld> master bssid |
| [`988-topology-query-without-node.patch`](../iopsys/overlay/map-agent/patches/988-topology-query-without-node.patch) | map-agent 988: answer a Topology Query from two hops away |
| [`989-no-bss-for-mld-affiliated-link.patch`](../iopsys/overlay/map-agent/patches/989-no-bss-for-mld-affiliated-link.patch) | map-agent 989: a link of an AP-MLD does not get a BSS of its own |
| [`990-bound-iface-init-retry.patch`](../iopsys/overlay/map-agent/patches/990-bound-iface-init-retry.patch) | map-agent 990: a phantom interface must not silence the node |
| [`991-dynbh-settle-leaf-nonbest-band.patch`](../iopsys/overlay/map-agent/patches/991-dynbh-settle-leaf-nonbest-band.patch) | map-agent: 991 - settle dynbh upgrade loop for a non-best-band leaf |
| [`992-mlo-sta-eviction-grace.patch`](../iopsys/overlay/map-agent/patches/992-mlo-sta-eviction-grace.patch) | map-agent: 992 - grace before evicting an MLO client |
| [`993-no-persist-bbss-assoc-block.patch`](../iopsys/overlay/map-agent/patches/993-no-persist-bbss-assoc-block.patch) | map-agent: 993 - never persist a backhaul BSS association block |
| [`993-num-sta-not-from-a-lying-hal.patch`](../iopsys/overlay/map-agent/patches/993-num-sta-not-from-a-lying-hal.patch) | map-agent: 993 - do not take a zero client count from a HAL that has the clients |
| [`994-island-prevention-check-cntlr-reachable.patch`](../iopsys/overlay/map-agent/patches/994-island-prevention-check-cntlr-reachable.patch) | map-agent: 994 - island prevention must check the uplink reaches the controller |
| [`995-bstamld-query-status.patch`](../iopsys/overlay/map-agent/patches/995-bstamld-query-status.patch) | map-agent 995: ask the bSTA MLD for status, or it never bridges |
| [`996-mld-netdev-is-own-setup-link.patch`](../iopsys/overlay/map-agent/patches/996-mld-netdev-is-own-setup-link.patch) | map-agent 996: the MLD netdev is its own setup link |
| [`997-empty-ap-mld-config-is-not-teardown.patch`](../iopsys/overlay/map-agent/patches/997-empty-ap-mld-config-is-not-teardown.patch) | map-agent 997: an empty AP MLD Config TLV is not a teardown order |
| [`998-multiap-default-bsta-priority.patch`](../iopsys/overlay/map-agent/patches/998-multiap-default-bsta-priority.patch) | map-agent 998: default the bSTA priority lookup like its siblings |
| [`999-disabled-bsta-is-not-a-bsta.patch`](../iopsys/overlay/map-agent/patches/999-disabled-bsta-is-not-a-bsta.patch) | map-agent 999: a disabled bSTA is not a bSTA |
| [`9991-fix-agent-status-bsta-mld-json.patch`](../iopsys/overlay/map-agent/patches/9991-fix-agent-status-bsta-mld-json.patch) | map-agent 9991: make `ubus call map.agent status` parse |
| [`9992-identify-controller-by-al-address.patch`](../iopsys/overlay/map-agent/patches/9992-identify-controller-by-al-address.patch) | map-agent 9992: identify the controller by its AL address |
| [`9993-receive-path-for-tid-to-link-policy.patch`](../iopsys/overlay/map-agent/patches/9993-receive-path-for-tid-to-link-policy.patch) | map-agent 9993: receive path for a TID-to-Link Mapping policy |
| [`9994-mld-bss-refresh-uses-mld-netdev.patch`](../iopsys/overlay/map-agent/patches/9994-mld-bss-refresh-uses-mld-netdev.patch) | map-agent 9994: ask the MLD netdev in stage 1 of the BSS refresh |
| [`9995-affiliated-stations-from-apmld.patch`](../iopsys/overlay/map-agent/patches/9995-affiliated-stations-from-apmld.patch) | map-agent 9995: read affiliated stations from wifi.apmld, not wifi.ap |
| [`9997-ap-stats-resolve-object-by-name.patch`](../iopsys/overlay/map-agent/patches/9997-ap-stats-resolve-object-by-name.patch) | map-agent 9997: fetch AP stats from the object the name says, not a stale id |
| [`9998-ap-stats-mld-name-and-backoff.patch`](../iopsys/overlay/map-agent/patches/9998-ap-stats-mld-name-and-backoff.patch) | map-agent 9998: take the MLD name from the BSS, and stop asking every second |
| [`9999-steer-the-mld-not-the-link.patch`](../iopsys/overlay/map-agent/patches/9999-steer-the-mld-not-the-link.patch) | map-agent 9999: steer the MLD, not the link that happens to be first |
| [`99991-agent-release-departed-clients.patch`](../iopsys/overlay/map-agent/patches/99991-agent-release-departed-clients.patch) | map-agent 99991: let a client go when the HAL says it is gone |
| [`99992-steer-search-the-whole-mld.patch`](../iopsys/overlay/map-agent/patches/99992-steer-search-the-whole-mld.patch) | map-agent 99992: look for the client across the whole MLD, not one BSS |
| [`99993-subscribe-frames-on-the-mld.patch`](../iopsys/overlay/map-agent/patches/99993-subscribe-frames-on-the-mld.patch) | map-agent 99993: subscribe to frames on the MLD, so they actually arrive |
| [`99994-sta-metrics-from-the-right-link.patch`](../iopsys/overlay/map-agent/patches/99994-sta-metrics-from-the-right-link.patch) | map-agent 99994: report a client from the link it is held under |
| [`99995-mld-master-status-is-not-the-link-bssid.patch`](../iopsys/overlay/map-agent/patches/99995-mld-master-status-is-not-the-link-bssid.patch) | map-agent 99995: the MLD master status is not the affiliated link's BSSID |
| [`99996-btm-response-ap-by-bssid.patch`](../iopsys/overlay/map-agent/patches/99996-btm-response-ap-by-bssid.patch) | map-agent: name the BTM-response AP by BSSID, not by ifname |
| [`99997-an-already-known-sta-is-not-a-failed-add.patch`](../iopsys/overlay/map-agent/patches/99997-an-already-known-sta-is-not-a-failed-add.patch) | map-agent: an already-known STA is not a failed add |
| [`99998-release-the-mld-address-entry-with-its-sta-mld.patch`](../iopsys/overlay/map-agent/patches/99998-release-the-mld-address-entry-with-its-sta-mld.patch) | map-agent: release the MLD-address entry with its STA-MLD |
| [`99999-master-status-only-bootstraps-link-fields.patch`](../iopsys/overlay/map-agent/patches/99999-master-status-only-bootstraps-link-fields.patch) | map-agent 99999: the MLD master status only bootstraps per-link fields |
| [`999991-stations-comment-tells-the-truth.patch`](../iopsys/overlay/map-agent/patches/999991-stations-comment-tells-the-truth.patch) | map-agent: the affiliated-stations comment described the code it replaced |
| [`999992-bssload-follows-master-again.patch`](../iopsys/overlay/map-agent/patches/999992-bssload-follows-master-again.patch) | map-agent: bssload follows the master again |
| [`999993-wsc-m2-livelock-and-bstamld-teardown-guard.patch`](../iopsys/overlay/map-agent/patches/999993-wsc-m2-livelock-and-bstamld-teardown-guard.patch) | map-agent: stop the WSC M2 livelock and the empty-BSTA-MLD teardowns |
| [`999994-num-sta-follows-the-station-list.patch`](../iopsys/overlay/map-agent/patches/999994-num-sta-follows-the-station-list.patch) | map-agent: num_sta follows the station list |
| [`999995-mld-must-not-overwrite-a-counted-num-sta.patch`](../iopsys/overlay/map-agent/patches/999995-mld-must-not-overwrite-a-counted-num-sta.patch) | map-agent: the MLD must not overwrite a counted num_sta |
| [`999996-refresh-attaches-the-leg-to-its-mld.patch`](../iopsys/overlay/map-agent/patches/999996-refresh-attaches-the-leg-to-its-mld.patch) | The MLD refresh created the station and left it an orphan |
| [`999997-ttlm-policy-rides-service-prioritization.patch`](../iopsys/overlay/map-agent/patches/999997-ttlm-policy-rides-service-prioritization.patch) | map-agent: take the TTLM policy from the Service Prioritization Request |
| [`999998-ttlm-capability-lives-in-bits-7-6.patch`](../iopsys/overlay/map-agent/patches/999998-ttlm-capability-lives-in-bits-7-6.patch) | map-agent: read the TTLM capability from bits 7-6 |
| [`999999-akm-suites-from-ap-sections.patch`](../iopsys/overlay/map-agent/patches/999999-akm-suites-from-ap-sections.patch) | map-agent: take AKM suites from the BSSes, not from the radio |
| [`9999997-akm-suites-split-by-haul.patch`](../iopsys/overlay/map-agent/patches/9999997-akm-suites-split-by-haul.patch) | map-agent: split advertised AKM suites by haul, not by iftype |
| [`9999998-assoc-control-block-must-block.patch`](../iopsys/overlay/map-agent/patches/9999998-assoc-control-block-must-block.patch) | map-agent: a block that blocks nothing is worse than no block |
| [`9999999-poll-attaches-the-leg-to-its-mld.patch`](../iopsys/overlay/map-agent/patches/9999999-poll-attaches-the-leg-to-its-mld.patch) | map-agent: the poll must attach a leg to its MLD too |
| [`99999991-a-local-ap-section-is-not-the-controllers-to-delete.patch`](../iopsys/overlay/map-agent/patches/99999991-a-local-ap-section-is-not-the-controllers-to-delete.patch) | map-agent 9999998: an 'ap' section the controller never sent is not the controller's to delete |
| [`99999992-a-generated-ifname-must-be-free-where-it-is-written.patch`](../iopsys/overlay/map-agent/patches/99999992-a-generated-ifname-must-be-free-where-it-is-written.patch) | map-agent 9999999: a generated interface name must be free in the registry it is written into |
| [`99999993-count-what-was-written.patch`](../iopsys/overlay/map-agent/patches/99999993-count-what-was-written.patch) | map-agent: count what was written, not what was intended |
| [`99999994-a-tlv-has-a-length-and-it-must-be-used.patch`](../iopsys/overlay/map-agent/patches/99999994-a-tlv-has-a-length-and-it-must-be-used.patch) | map-agent: a TLV has a length, and the traffic-separation reader must use it |
| [`99999995-every-link-not-just-the-first.patch`](../iopsys/overlay/map-agent/patches/99999995-every-link-not-just-the-first.patch) | map-agent: an MLD has every link, not just the first |
| [`99999996-borrow-the-measurement-not-the-identity.patch`](../iopsys/overlay/map-agent/patches/99999996-borrow-the-measurement-not-the-identity.patch) | map-agent: borrow the measurement, not the identity |
| [`99999997-the-mld-entry-has-no-link-of-its-own.patch`](../iopsys/overlay/map-agent/patches/99999997-the-mld-entry-has-no-link-of-its-own.patch) | map-agent: the MLD entry has no link of its own |
| [`99999998-answer-for-the-client-that-was-asked-about.patch`](../iopsys/overlay/map-agent/patches/99999998-answer-for-the-client-that-was-asked-about.patch) | map-agent: answer for the client that was asked about |
| [`99999999-every-link-of-an-ap-mld-gets-the-new-credentials.patch`](../iopsys/overlay/map-agent/patches/99999999-every-link-of-an-ap-mld-gets-the-new-credentials.patch) | map-agent: apply SSID/PSK changes to every affiliated link of an AP MLD |
| [`99999999a-local-mld-adopts-the-controller-credentials.patch`](../iopsys/overlay/map-agent/patches/99999999a-local-mld-adopts-the-controller-credentials.patch) | map-agent: local MLDs adopt the credentials of a controller without MLD config |
| [`99999999c-bsta-steer-on-an-mlo-bsta-does-not-pin-a-link.patch`](../iopsys/overlay/map-agent/patches/99999999c-bsta-steer-on-an-mlo-bsta-does-not-pin-a-link.patch) | map-agent: steer an MLO bSTA without pinning a link BSSID |
| [`99999999d-wireless-reload-skips-an-unchanged-config.patch`](../iopsys/overlay/map-agent/patches/99999999d-wireless-reload-skips-an-unchanged-config.patch) | map-agent: wireless_reload skips a config that is already applied |
| [`99999999e-ttlm-pin-gets-a-fuse-and-a-teardown.patch`](../iopsys/overlay/map-agent/patches/99999999e-ttlm-pin-gets-a-fuse-and-a-teardown.patch) | map-agent: give a TTLM pin a fuse, and a way to be undone |
| [`99999999f-bsta-mld-reported-with-e1-not-cb.patch`](../iopsys/overlay/map-agent/patches/99999999f-bsta-mld-reported-with-e1-not-cb.patch) | map-agent: a bSTA MLD is reported with 0xE1, not with 0xCB |
| [`99999999g-ext-link-metrics-under-queried-address.patch`](../iopsys/overlay/map-agent/patches/99999999g-ext-link-metrics-under-queried-address.patch) | map-agent: extended link metrics answer under the queried address |
| [`99999999h-add-missed-ap-mld-stations-every-minute.patch`](../iopsys/overlay/map-agent/patches/99999999h-add-missed-ap-mld-stations-every-minute.patch) | map-agent: add missed AP MLD station links once a minute |

## iopsys libwifi

The Wi-Fi abstraction the iopsys stack talks to.

| Patch | What it does |
|---|---|
| [`900-hal-bsta-status.patch`](../iopsys/overlay/libwifi/patches/900-hal-bsta-status.patch) | libwifi: hal bsta status |
| [`910-phase2-event-cache.patch`](../iopsys/overlay/libwifi/patches/910-phase2-event-cache.patch) | libwifi: phase2 event cache |
| [`920-ap-mld-event-cache.patch`](../iopsys/overlay/libwifi/patches/920-ap-mld-event-cache.patch) | libwifi: ap mld event cache |
| [`921-apconn-cache-fix-spin.patch`](../iopsys/overlay/libwifi/patches/921-apconn-cache-fix-spin.patch) | libwifi: apconn cache fix spin |
| [`922-hostapd-ctrl-publishes-wifi-sta.patch`](../iopsys/overlay/libwifi/patches/922-hostapd-ctrl-publishes-wifi-sta.patch) | libwifi: publish wifi.sta from the hostapd ctrl socket |
| [`923-publish-btm-response.patch`](../iopsys/overlay/libwifi/patches/923-publish-btm-response.patch) | libwifi: publish the BTM Response as wifi.sta btm-resp |
| [`924-bss-entry-of-this-socket.patch`](../iopsys/overlay/libwifi/patches/924-bss-entry-of-this-socket.patch) | libwifi: take the BSS entry that belongs to this socket |
| [`925-legacy-client-is-not-an-mld.patch`](../iopsys/overlay/libwifi/patches/925-legacy-client-is-not-an-mld.patch) | libwifi: a legacy client on an MLD AP is not an MLD |
| [`931-driver-lookup-ap-mld-name.patch`](../iopsys/overlay/libwifi/patches/931-driver-lookup-ap-mld-name.patch) | libwifi: driver lookup ap mld name |
| [`934-wpactrl-chmod-client-socket.patch`](../iopsys/overlay/libwifi/patches/934-wpactrl-chmod-client-socket.patch) | libwifi: wpactrl chmod client socket |
| [`935-backhaul-mld-driver-name.patch`](../iopsys/overlay/libwifi/patches/935-backhaul-mld-driver-name.patch) | libwifi: advertise the bsta-mld driver-name token |
| [`936-mlsta-tolerate-band-enrich-failure.patch`](../iopsys/overlay/libwifi/patches/936-mlsta-tolerate-band-enrich-failure.patch) | libwifi: tolerate per-band enrich failure in iface_get_mlsta_info |
| [`937-mld-station-hostapd-enrich-unconditional.patch`](../iopsys/overlay/libwifi/patches/937-mld-station-hostapd-enrich-unconditional.patch) | libwifi: 937 - enumerate MLD stations via hostapd unconditionally |
| [`938-mlsta-bsta-mld-status-mt76.patch`](../iopsys/overlay/libwifi/patches/938-mlsta-bsta-mld-status-mt76.patch) | libwifi: make bSTA-MLD status survive mt76 per-link gaps |
| [`939-mlsta-keep-per-link-identity.patch`](../iopsys/overlay/libwifi/patches/939-mlsta-keep-per-link-identity.patch) | libwifi 939: keep the per-link identity across the mlsta band enrichment |
| [`940-per-link-station-metrics.patch`](../iopsys/overlay/libwifi/patches/940-per-link-station-metrics.patch) | libwifi 940: read the per-link station metrics nl80211 already returns |
| [`941-report-4addr-sta-mld.patch`](../iopsys/overlay/libwifi/patches/941-report-4addr-sta-mld.patch) | libwifi: a 4-address STA-MLD gets its identity, not an all-zero station |
| [`942-4addr-sta-mld-is-mlo-capable.patch`](../iopsys/overlay/libwifi/patches/942-4addr-sta-mld-is-mlo-capable.patch) | libwifi: a 4-address STA-MLD with two links is MLO capable |
| [`943-block-sta-must-reach-every-mld-link.patch`](../iopsys/overlay/libwifi/patches/943-block-sta-must-reach-every-mld-link.patch) | libwifi: a block on an AP-MLD must reach every affiliated link |
| [`944-ctrl-socket-must-follow-the-requested-band.patch`](../iopsys/overlay/libwifi/patches/944-ctrl-socket-must-follow-the-requested-band.patch) | libwifi: honour the requested band when picking a ctrl socket |
| [`945-akm-suite-copy-takes-a-count-not-a-length.patch`](../iopsys/overlay/libwifi/patches/945-akm-suite-copy-takes-a-count-not-a-length.patch) | libwifi: AKM suite copy takes a count, not a byte length |
| [`946-hostapd-measured-the-signal-so-read-it.patch`](../iopsys/overlay/libwifi/patches/946-hostapd-measured-the-signal-so-read-it.patch) | libwifi: hostapd measured the signal, so read it |
| [`947-4addr-sta-mld-links-from-its-vlan.patch`](../iopsys/overlay/libwifi/patches/947-4addr-sta-mld-links-from-its-vlan.patch) | libwifi: read the links of a 4-address STA-MLD from its VLAN netdev |

## iopsys wifimngr

| Patch | What it does |
|---|---|
| [`900-hal-bsta-status.patch`](../iopsys/overlay/wifimngr/patches/900-hal-bsta-status.patch) | wifimngr: hal bsta status |
| [`910-event-rearm-pace.patch`](../iopsys/overlay/wifimngr/patches/910-event-rearm-pace.patch) | wifimngr: event rearm pace |

## Kernel, U-Boot and board support

Device tree, boot from NVMe, Ethernet and SFP fixes.

| Patch | What it does |
|---|---|
| [`453-w-add-bpi-r4-nvme-dtso.patch`](../patches/kernel/453-w-add-bpi-r4-nvme-dtso.patch) | arm64: dts: mediatek: mt7988a: add BPI-R4 NVMe root disk overlay |
| [`999-fitblk-02-w-add-bpi-r4-nvme-fitblk.patch`](../patches/kernel/999-fitblk-02-w-add-bpi-r4-nvme-fitblk.patch) | block: fitblk: find the FIT image on an NVMe root disk |
| [`999-vendor-01-amnt-macaddr-flat.patch`](../patches/mtk-feed/999-vendor-01-amnt-macaddr-flat.patch) | mt76-vendor: send the air-monitor MAC as six bytes, not as a nest |
| [`999-eth-21-mtk-gdm-rx-fsm-reset.patch`](../patches/mtk-feed/kernel/999-eth-21-mtk-gdm-rx-fsm-reset.patch) | net: ethernet: mtk_eth_soc: reset GDM Rx FSM on 10G->1G mode change |
| [`999-pcs-10-lynxi-hold-link-down-on-invalid-speed.patch`](../patches/mtk-feed/kernel/999-pcs-10-lynxi-hold-link-down-on-invalid-speed.patch) | net: pcs: mtk-lynxi: don't report link up with unresolved |
| [`999-sfp-10-additional-quirks.patch`](../patches/mtk-feed/kernel/999-sfp-10-additional-quirks.patch) | SFP module quirks (additional entries in the quirk table) *(by -)* |
| [`999-sfp-11-rtl8261be-mdio-none.patch`](../patches/mtk-feed/kernel/999-sfp-11-rtl8261be-mdio-none.patch) | net: phy: sfp: probe for RollBall I2C-to-MDIO bridge in mdio-i2c |
| [`999-sfp-22-rtl8261be-boot-1g-reprobe.patch`](../patches/mtk-feed/kernel/999-sfp-22-rtl8261be-boot-1g-reprobe.patch) | net: phy: sfp: re-probe an RTL8261BE module that came up at 1G |
| [`450-add-bpi-r4.patch`](../patches/uboot/450-add-bpi-r4.patch) | uboot-mediatek: add Bananapi BPI-R4 *(by Daniel Golle)* |
| [`451-add-bpi-r4-nvme.patch`](../patches/uboot/451-add-bpi-r4-nvme.patch) | uboot-mediatek: BPI-R4: enable NVMe support |
| [`452-add-bpi-r4-nvme-rfb.patch`](../patches/uboot/452-add-bpi-r4-nvme-rfb.patch) | uboot-mediatek: mt7988: bring up NVMe on the BPI-R4 |

## LuCI

| Patch | What it does |
|---|---|
| [`0001-luci-mod-system-current-and-new-password.patch`](../patches/luci/0001-luci-mod-system-current-and-new-password.patch) | luci-mod-system: current and new password; empty removes it |
