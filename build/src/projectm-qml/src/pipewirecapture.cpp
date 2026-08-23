#include "pipewirecapture.h"

#include <cstdint>
#include <mutex>

#include <spa/param/audio/format-utils.h>

#include "pcmringbuffer.h"

namespace {
std::once_flag pwInitFlag;
}

PipeWireCapture::PipeWireCapture(PcmRingBuffer *ring)
    : m_ring(ring)
{
}

PipeWireCapture::~PipeWireCapture()
{
    stop();
}

void PipeWireCapture::processTrampoline(void *userdata)
{
    static_cast<PipeWireCapture *>(userdata)->handleProcess();
}

void PipeWireCapture::stateTrampoline(void *userdata, pw_stream_state /*oldState*/,
                                      pw_stream_state state, const char * /*error*/)
{
    auto *self = static_cast<PipeWireCapture *>(userdata);
    if (self->onStreamingChanged)
        self->onStreamingChanged(state == PW_STREAM_STATE_STREAMING);
}

void PipeWireCapture::start()
{
    if (m_loop)
        return;

    std::call_once(pwInitFlag, [] { pw_init(nullptr, nullptr); });

    m_loop = pw_thread_loop_new("lateralus-viz", nullptr);
    if (!m_loop)
        return;

    static const pw_stream_events streamEvents = {
        .version = PW_VERSION_STREAM_EVENTS,
        .state_changed = &PipeWireCapture::stateTrampoline,
        .process = &PipeWireCapture::processTrampoline,
    };

    // PW_KEY_STREAM_CAPTURE_SINK makes this a monitor capture of the default
    // sink, and PipeWire re-routes it automatically when the default changes.
    pw_properties *props = pw_properties_new(
        PW_KEY_MEDIA_TYPE, "Audio",
        PW_KEY_MEDIA_CATEGORY, "Capture",
        PW_KEY_MEDIA_ROLE, "Music",
        PW_KEY_STREAM_CAPTURE_SINK, "true",
        PW_KEY_NODE_NAME, "lateralus-visualizer",
        nullptr);

    m_stream = pw_stream_new_simple(pw_thread_loop_get_loop(m_loop),
                                    "lateralus-visualizer", props, &streamEvents, this);
    if (!m_stream) {
        pw_thread_loop_destroy(m_loop);
        m_loop = nullptr;
        return;
    }

    // F32 interleaved stereo; the rate is left to the graph — projectM's beat
    // detection is insensitive to 44.1 vs 48 kHz at this fidelity.
    uint8_t buffer[1024];
    spa_pod_builder podBuilder = SPA_POD_BUILDER_INIT(buffer, sizeof(buffer));
    spa_audio_info_raw info{};
    info.format = SPA_AUDIO_FORMAT_F32;
    info.channels = 2;
    const spa_pod *params[1];
    params[0] = spa_format_audio_raw_build(&podBuilder, SPA_PARAM_EnumFormat, &info);

    pw_stream_connect(m_stream, PW_DIRECTION_INPUT, PW_ID_ANY,
                      static_cast<pw_stream_flags>(PW_STREAM_FLAG_AUTOCONNECT
                                                   | PW_STREAM_FLAG_MAP_BUFFERS),
                      params, 1);

    pw_thread_loop_start(m_loop);
}

void PipeWireCapture::stop()
{
    if (!m_loop)
        return;

    // Joining the loop thread first means the stream and loop can then be
    // destroyed without locking — nothing else runs anymore.
    pw_thread_loop_stop(m_loop);
    pw_stream_destroy(m_stream);
    m_stream = nullptr;
    pw_thread_loop_destroy(m_loop);
    m_loop = nullptr;
}

void PipeWireCapture::handleProcess()
{
    pw_buffer *pwBuffer = pw_stream_dequeue_buffer(m_stream);
    if (!pwBuffer)
        return;

    const spa_data &data = pwBuffer->buffer->datas[0];
    if (data.data && data.chunk && data.chunk->size > 0) {
        const auto *bytes = static_cast<const uint8_t *>(data.data) + data.chunk->offset;
        m_ring->write(reinterpret_cast<const float *>(bytes),
                      data.chunk->size / sizeof(float));
    }

    pw_stream_queue_buffer(m_stream, pwBuffer);
}
