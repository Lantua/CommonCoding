//
//  UnkeyedOptimizer.swift
//  
//
//  Created by Natchanon Luangsomboon on 20/2/2563 BE.
//

import Foundation

struct UnkeyedOptimizer: EncodingOptimizer {
    var header = Header.nil
    private var values: [EncodingOptimizer]
    private(set) var payloadSize = 0

    init(values: [EncodingOptimizer]) {
        self.values = values
    }

    mutating func optimize(for context: OptimizationContext) {
        for index in values.indices {
            values[index].optimize(for: context)
        }

        var bestOption = regularSize()
        var bestSize = bestOption.header.size + bestOption.payload

        func compare(candidate: (header: Header, payload: Int)) {
            let candidateSize = candidate.header.size + candidate.payload
            if candidateSize <= bestSize {
                bestOption = candidate
                bestSize = candidateSize
            }
        }

        if let candidate = equisizeSize() {
            compare(candidate: candidate)
        }

        if let candidate = uniformSize() {
            compare(candidate: candidate)
        }

        (header, payloadSize) = bestOption
    }

    func writePayload(to data: Slice<UnsafeMutableRawBufferPointer>) {
        assert(data.count >= payloadSize)

        var data = data

        switch header {
        case let .equisizeUnkeyed(header):
            let size = header.payloadSize
            if header.subheader != nil {
                for value in values {
                    value.writePayload(to: data.prefix(size))
                    data.removeFirst(size)
                }
            } else {
                for value in values {
                    value.write(to: data.prefix(size))
                    data.removeFirst(size)
                }
            }
        default:
            assert(header.tag == .regularUnkeyed)

            for value in values {
                let size = value.size
                value.write(to: data.prefix(size))
                data.removeFirst(size)
            }
        }
    }
}

private extension UnkeyedOptimizer {
    func regularSize() -> (header: Header, payload: Int) {
        let sizes = values.lazy.map { $0.size }
        let header = Header.regularUnkeyed(.init(sizes: Array(sizes)))
        return (header, sizes.reduce(0, +))
    }

    func equisizeSize() -> (header: Header, payload: Int)? {
        let maxSize = values.lazy.map { $0.size }.reduce(0, max)
        guard maxSize > 0 else {
            return nil
        }
        return (.equisizeUnkeyed(.init(itemSize: maxSize, subheader: nil, count: values.count)), maxSize * values.count)
    }

    func uniformSize() -> (header: Header, payload: Int)? {
        guard let (itemSize, subheader) = uniformize(values: values) else {
            return nil
        }

        return (.equisizeUnkeyed(.init(itemSize: itemSize, subheader: subheader, count: values.count)), (itemSize - subheader.size) * values.count)
    }
}
