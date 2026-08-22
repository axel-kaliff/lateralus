#pragma once

#include <functional>

#include <pipewire/pipewire.h>

class PcmRingBuffer;

// Captures the default audio sink's monitor into a PcmRingBuffer via a
// pw_stream running on its own pw_thread_loop. start()/stop() are GUI-thread
// calls; the process callback runs on the PipeWire loop thread and only
// touches the lock-free ring.
class PipeWireCapture {
public:
    explicit PipeWireCapture(PcmRingBuffer *ring);
    ~PipeWireCapture();
    PipeWireCapture(const PipeWireCapture &) = delete;
    PipeWireCapture &operator=(const PipeWireCapture &) = delete;

    void start();
    void stop();
    bool running() const { return m_loop != nullptr; }

    // Invoked from the PipeWire loop thread when the stream enters/leaves the
    // streaming state; the receiver must marshal to its own thread.
    std::function<void(bool)> onStreamingChanged;

private:
    static void processTrampoline(void *userdata);
    static void stateTrampoline(void *userdata, pw_stream_state oldState,
                                pw_stream_state state, const char *error);
    void handleProcess();

    PcmRingBuffer *m_ring = nullptr;
    pw_thread_loop *m_loop = nullptr;
    pw_stream *m_stream = nullptr;
};
