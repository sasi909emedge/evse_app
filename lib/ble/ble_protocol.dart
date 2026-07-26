import 'dart:typed_data';
import 'package:flutter/foundation.dart';
// ================================================================
// EMEDGE BLE PROTOCOL — Company Spec
//
// Packet structure:
//   Byte 0-3  : Total JSON Length  (uint32 LITTLE-endian)
//   Byte 4-5  : Total Chunks       (uint16 LITTLE-endian)
//   Byte 6-7  : Current Chunk      (uint16 LITTLE-endian, 1-based)
//   Byte 8    : Selection          (0=UPDATE_CONFIG, 1=REQUEST)
//   Byte 9    : Format             (0=INVALID, 1=JSON, 2=BINARY, 3=FIRMWARE)
//   Byte 10+  : JSON Payload       (actual payload bytes only — NOT padded)
//   Last 2    : Reserved 0x00 0x00
//
// KEY FIX: Each packet size = HEADER(10) + ACTUAL_PAYLOAD + RESERVED(2)
// NOT always 512 bytes — only as many bytes as needed for that chunk
//
// Example 704 bytes JSON:
//   Chunk 1: 10 + 500 + 2 = 512 bytes  (full)
//   Chunk 2: 10 + 204 + 2 = 216 bytes  (remaining only)
//
// Example 1680 bytes JSON:
//   Chunk 1: 10 + 500 + 2 = 512 bytes  (full)
//   Chunk 2: 10 + 500 + 2 = 512 bytes  (full)
//   Chunk 3: 10 + 500 + 2 = 512 bytes  (full)
//   Chunk 4: 10 + 180 + 2 = 192 bytes  (remaining only)
// ================================================================

class Selection {
  static const int request              = 0;
  static const int updateConfig         = 1;
  static const int updateMeterConfig    = 2;
  static const int updateConnectorConfig= 3;
  static const int updatePowerModule    = 4;

  static const int requestConfig            = 11;
  static const int requestMeterConfig       = 12;
  static const int requestConnectorConfig   = 13;
  static const int requestPowerModuleConfig = 14;
}

class DataFormat {
  static const int invalid = 0;
  static const int json = 1;
  static const int binaryData = 2;
  static const int firmwareBinary = 3;
}

class BleProtocol {
  static const int headerSize = 10;
  static const int reservedSize = 0;
  static const int maxPacket = 240; // Max BLE write size on charger
  // Max payload per chunk = 240 - 10 header - 0 reserved = 230 bytes
  static const int payloadSize = maxPacket - headerSize - reservedSize;

  // ── Build packets ────────────────────────────────────────────
  static List<Uint8List> buildPackets(
    List<int> data, {
    int selection = Selection.updateConfig,
    int format = DataFormat.json,
  }) {
    final total = data.length;
    final numChunks =
        total == 0 ? 1 : ((total + payloadSize - 1) ~/ payloadSize);

    final packets = <Uint8List>[];

    // Chunks are 1-BASED: chunk 1, 2, 3 ... numChunks
    for (int chunk = 1; chunk <= numChunks; chunk++) {
      final start = (chunk - 1) * payloadSize;
      final end = (start + payloadSize < total) ? start + payloadSize : total;
      final chunkData = total == 0 ? <int>[] : data.sublist(start, end);
      final bytesToCopy = chunkData.length;

      // KEY FIX: Packet size = header + ACTUAL bytes + reserved
      // NOT always 512 — avoids write overflow on charger
      final packetSize = headerSize + bytesToCopy + reservedSize;
      final packet = Uint8List(packetSize);

      // ── Header LITTLE-ENDIAN ────────────────────────────────
      // Bytes 0-3: Total length
      packet[0] = (total) & 0xFF;
      packet[1] = (total >> 8) & 0xFF;
      packet[2] = (total >> 16) & 0xFF;
      packet[3] = (total >> 24) & 0xFF;

      // Bytes 4-5: Total chunks
      packet[4] = (numChunks) & 0xFF;
      packet[5] = (numChunks >> 8) & 0xFF;

      // Bytes 6-7: Current chunk (1-based)
      packet[6] = (chunk) & 0xFF;
      packet[7] = (chunk >> 8) & 0xFF;

      // Byte 8: Selection
      packet[8] = selection & 0xFF;

      // Byte 9: Format
      packet[9] = format & 0xFF;

      // ── Payload ─────────────────────────────────────────────
      for (int i = 0; i < bytesToCopy; i++) {
        packet[headerSize + i] = chunkData[i];
      }
      // ── Reserved (last 2 bytes) ──────────────────────────────
    //   packet[packetSize - 2] = 0x00;
    //   packet[packetSize - 1] = 0x00;

      packets.add(packet);
    }

    return packets;
  }

  // ── Parse received notify packet ─────────────────────────────
  static ParsedPacket? parse(List<int> raw) {
    if (raw.length < headerSize) return null;

    // LITTLE-ENDIAN
    final totalLength =
        raw[0] | (raw[1] << 8) | (raw[2] << 16) | (raw[3] << 24);

    final totalChunks = raw[4] | (raw[5] << 8);
    final chunkIndex = raw[6] | (raw[7] << 8); // 1-based
    final selection = raw[8];
    final format = raw[9];

    // Payload = everything after header except last 2 reserved bytes
    final payloadEnd =
    raw.length >= reservedSize ? raw.length - reservedSize : raw.length;

    final payload = raw.length > headerSize
        ? raw.sublist(

            headerSize, payloadEnd > headerSize ? payloadEnd : raw.length)
        : <int>[];

    return ParsedPacket(
      totalLength: totalLength,
      totalChunks: totalChunks,
      chunkIndex: chunkIndex,
      selection: selection,
      format: format,
      payload: payload,
    );
  }
}

class ParsedPacket {
  final int totalLength;
  final int totalChunks;
  final int chunkIndex; // 1-based
  final int selection;
  final int format;
  final List<int> payload;

  bool get isLast => chunkIndex == totalChunks;

  const ParsedPacket({
    required this.totalLength,
    required this.totalChunks,
    required this.chunkIndex,
    required this.selection,
    required this.format,
    required this.payload,
  });

  @override
  String toString() => 'Packet[len=$totalLength '
      'chunk=$chunkIndex/$totalChunks '
      'sel=$selection fmt=$format '
      'payload=${payload.length}B]';
}
