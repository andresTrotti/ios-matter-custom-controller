/*
 *
 *    Copyright (c) 2022 Project CHIP Authors
 *
 *    Licensed under the Apache License, Version 2.0 (the "License");
 *    you may not use this file except in compliance with the License.
 *    You may obtain a copy of the License at
 *
 *        http://www.apache.org/licenses/LICENSE-2.0
 *
 *    Unless required by applicable law or agreed to in writing, software
 *    distributed under the License is distributed on an "AS IS" BASIS,
 *    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *    See the License for the specific language governing permissions and
 *    limitations under the License.
 */


// DO NOT EDIT - Generated file
//
// Application configuration for WiFiNetworkDiagnostics based on EMBER configuration
#pragma once

#include <app/util/cluster-config.h>
#include <clusters/WiFiNetworkDiagnostics/AttributeIds.h>
#include <clusters/WiFiNetworkDiagnostics/CommandIds.h>
#include <clusters/WiFiNetworkDiagnostics/Enums.h>

#include <array>

namespace chip {
namespace app {
namespace Clusters {
namespace WiFiNetworkDiagnostics {
namespace StaticApplicationConfig {
namespace detail {
inline constexpr AttributeId kEndpoint0EnabledAttributes[] = {
    Attributes::Bssid::Id,
    Attributes::SecurityType::Id,
    Attributes::WiFiVersion::Id,
    Attributes::ChannelNumber::Id,
    Attributes::Rssi::Id,
    Attributes::BeaconLostCount::Id,
    Attributes::BeaconRxCount::Id,
    Attributes::PacketMulticastRxCount::Id,
    Attributes::PacketMulticastTxCount::Id,
    Attributes::PacketUnicastRxCount::Id,
    Attributes::PacketUnicastTxCount::Id,
    Attributes::CurrentMaxRate::Id,
    Attributes::OverrunCount::Id,
    Attributes::FeatureMap::Id,
    Attributes::ClusterRevision::Id,
};
} // namespace detail

using FeatureBitmapType = Feature;

inline constexpr std::array<Clusters::StaticApplicationConfig::ClusterConfiguration<FeatureBitmapType>, 1 + 0> kFixedClusterConfig = { {
    {
        .endpointNumber = 0,
        .featureMap = BitFlags<FeatureBitmapType> {
            FeatureBitmapType::kPacketCounts, // feature bit 0x1
            FeatureBitmapType::kErrorCounts, // feature bit 0x2
        },
        .enabledAttributes =
            Span<const AttributeId>(detail::kEndpoint0EnabledAttributes),
        .enabledCommands =
            Span<const CommandId>(),
    },
} };

// If a specific attribute is supported at all across all endpoint static instantiations
inline constexpr bool IsAttributeEnabledOnSomeEndpoint(AttributeId attributeId) {
  switch (attributeId) {
    case Attributes::Bssid::Id:
      return true;
    case Attributes::ChannelNumber::Id:
      return true;
    case Attributes::Rssi::Id:
      return true;
    case Attributes::BeaconLostCount::Id:
      return true;
    case Attributes::BeaconRxCount::Id:
      return true;
    case Attributes::PacketMulticastRxCount::Id:
      return true;
    case Attributes::PacketMulticastTxCount::Id:
      return true;
    case Attributes::PacketUnicastRxCount::Id:
      return true;
    case Attributes::PacketUnicastTxCount::Id:
      return true;
    case Attributes::CurrentMaxRate::Id:
      return true;
    case Attributes::OverrunCount::Id:
      return true;
    case Attributes::FeatureMap::Id:
      return true;
    case Attributes::ClusterRevision::Id:
      return true;
    default:
      return false;
  }
}

// If a specific command is supported at all across all endpoint static instantiations
inline constexpr bool IsCommandEnabledOnSomeEndpoint(CommandId commandId) {
  switch (commandId) {
    default:
      return false;
  }
}

} // namespace StaticApplicationConfig
} // namespace WiFiNetworkDiagnostics
} // namespace Clusters
} // namespace app
} // namespace chip