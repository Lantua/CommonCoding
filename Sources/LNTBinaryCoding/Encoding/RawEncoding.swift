//
//  File.swift
//  
//
//  Created by Natchanon Luangsomboon on 20/2/2563 BE.
//

import Foundation

extension Header {
    /// Size of this header
    var size: Int {
        switch self {
        case .nil: return 0
        case .signed, .unsigned, .string: return 1
        case let .regularKeyed(header):
            return 2 + header.mapping.lazy.map { $0.key.vsuiSize + $0.size.vsuiSize }.reduce(0, +)
        case let .equisizeKeyed(header):
            if let subheader = header.subheader {
                return 2 + header.itemSize.vsuiSize + subheader.size + header.keys.lazy.map { $0.vsuiSize }.reduce(0, +)
            } else {
                return 2 + header.payloadSize.vsuiSize + header.keys.lazy.map { $0.vsuiSize }.reduce(0, +)
            }
        case let .regularUnkeyed(header):
            return 2 + header.sizes.lazy.map { $0.vsuiSize }.reduce(0, +)
        case let .equisizeUnkeyed(header):
            if let subheader = header.subheader {
                return 1 + header.itemSize.vsuiSize + subheader.size + header.count.vsuiSize
            } else {
                return 1 + header.payloadSize.vsuiSize + header.count.vsuiSize
            }
        }
    }

    /// Write the header to `data`, and remove the written part.
    func write(to data: inout Slice<UnsafeMutableRawBufferPointer>) {
        guard !data.isEmpty else {
            assert(size == 0)
            return
        }

        func append(_ value: UInt8) {
            data[data.startIndex] = value
            data.removeFirst()
        }

        append(tag.rawValue)

        switch self {
        case .nil, .signed, .unsigned, .string: break

        case let .regularKeyed(header):
            for (key, size) in header.mapping {
                size.write(to: &data)
                key.write(to: &data)
            }
            append(0x01)
        case let .equisizeKeyed(header):
            header.itemSize.write(to: &data)
            for key in header.keys {
                key.write(to: &data)
            }
            append(0x00)
            header.subheader?.write(to: &data)
        case let .regularUnkeyed(header):
            for size in header.sizes {
                size.write(to: &data)
            }
            append(0x01)
        case let .equisizeUnkeyed(header):
            header.itemSize.write(to: &data)
            header.count.write(to: &data)
            header.subheader?.write(to: &data)
        }
    }
}

extension Int {
    /// Size of this value, in bytes, when being written in VSUI format.
    var vsuiSize: Int {
        assert(self >= 0)
        return Swift.max((bitWidth - leadingZeroBitCount + 6) / 7, 1)
    }

    /// Write a VSUI value to `data` and remove the written part.
    func write(to data: inout Slice<UnsafeMutableRawBufferPointer>) {
        let size = vsuiSize

        let last = data.index(data.startIndex, offsetBy: size - 1)
        var value = self, index = last

        for i in 0..<size {
            data[index] = UInt8((value & 0x7f) | (i == 0 ? 0 : 0x80))

            data.formIndex(before: &index)
            value >>= 7
        }

        data[last] &= 0x7f
        assert(value == 0)
        
        data.removeFirst(size)
    }
}

extension FixedWidthInteger {
    func writeFixedWidth(to data: Slice<UnsafeMutableRawBufferPointer>) {
        assert(bitWidth / 8 <= data.count)
        
        withUnsafeBytes(of: self) { raw in
            UnsafeMutableRawBufferPointer(rebasing: data).copyMemory(from: raw)
        }
    }
}
