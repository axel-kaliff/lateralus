#pragma once

#include <array>
#include <atomic>
#include <cstddef>

// Single-producer single-consumer lock-free ring of interleaved stereo floats.
// Producer: the PipeWire loop thread. Consumer: the Qt Quick render thread.
//
// Indices grow monotonically and are masked on access, so head - tail is the
// fill level even across wraparound. When the ring is full the producer drops
// the newest samples: the consumer drains the whole ring every rendered frame,
// so a full ring means rendering has stalled and momentarily stale audio is
// preferable to corrupting the ring with concurrent index surgery.
class PcmRingBuffer {
public:
    static constexpr std::size_t Capacity = 16384; // floats; power of two

    std::size_t write(const float *src, std::size_t count)
    {
        const std::size_t head = m_head.load(std::memory_order_relaxed);
        const std::size_t tail = m_tail.load(std::memory_order_acquire);
        const std::size_t free = Capacity - (head - tail);
        const std::size_t n = count < free ? count : free;
        for (std::size_t i = 0; i < n; ++i)
            m_data[(head + i) & (Capacity - 1)] = src[i];
        m_head.store(head + n, std::memory_order_release);
        return n;
    }

    std::size_t read(float *dst, std::size_t max)
    {
        const std::size_t tail = m_tail.load(std::memory_order_relaxed);
        const std::size_t head = m_head.load(std::memory_order_acquire);
        const std::size_t avail = head - tail;
        const std::size_t n = avail < max ? avail : max;
        for (std::size_t i = 0; i < n; ++i)
            dst[i] = m_data[(tail + i) & (Capacity - 1)];
        m_tail.store(tail + n, std::memory_order_release);
        return n;
    }

private:
    std::array<float, Capacity> m_data{};
    std::atomic<std::size_t> m_head{0};
    std::atomic<std::size_t> m_tail{0};
};
