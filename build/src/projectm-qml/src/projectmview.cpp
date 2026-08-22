#include "projectmview.h"

#include <QQuickWindow>
#include <QSGRendererInterface>

#include "projectmrenderer.h"

namespace {
constexpr auto DEFAULT_PRESET_PATH = "/usr/share/projectM/presets/presets_milkdrop";
}

ProjectMView::ProjectMView(QQuickItem *parent)
    : QQuickFramebufferObject(parent)
    , m_ring(std::make_shared<PcmRingBuffer>())
    , m_capture(std::make_unique<PipeWireCapture>(m_ring.get()))
{
    m_controls.presetPath = QString::fromLatin1(DEFAULT_PRESET_PATH);

    m_capture->onStreamingChanged = [this](bool streaming) {
        QMetaObject::invokeMethod(
            this, [this, streaming] { setAudioActive(streaming); }, Qt::QueuedConnection);
    };

    m_timer.setInterval(1000 / m_controls.fps);
    connect(&m_timer, &QTimer::timeout, this, &QQuickItem::update);

    connect(this, &QQuickItem::visibleChanged, this, &ProjectMView::updateActive);
    connect(this, &QQuickItem::windowChanged, this, [this](QQuickWindow *window) {
        updateActive();
        if (window) {
            // sceneGraphInitialized is emitted on the render thread; marshal
            // the API check back to the GUI thread.
            connect(window, &QQuickWindow::sceneGraphInitialized, this,
                    &ProjectMView::updateApiSupport, Qt::QueuedConnection);
            updateApiSupport();
        }
    });
}

ProjectMView::~ProjectMView()
{
    // Stop the producer before the ring; the renderer keeps the ring alive
    // through its shared_ptr if it outlives the item on the render thread.
    m_timer.stop();
    m_capture->stop();
}

QQuickFramebufferObject::Renderer *ProjectMView::createRenderer() const
{
    return new ProjectMRenderer(m_ring);
}

void ProjectMView::setPresetPath(const QString &path)
{
    if (m_controls.presetPath == path)
        return;
    m_controls.presetPath = path;
    emit presetPathChanged();
    update();
}

void ProjectMView::setPresetDuration(int seconds)
{
    if (m_controls.presetDuration == seconds)
        return;
    m_controls.presetDuration = seconds;
    emit presetDurationChanged();
    update();
}

void ProjectMView::setShuffle(bool shuffle)
{
    if (m_controls.shuffle == shuffle)
        return;
    m_controls.shuffle = shuffle;
    emit shuffleChanged();
    update();
}

void ProjectMView::setPresetLocked(bool locked)
{
    if (m_controls.presetLocked == locked)
        return;
    m_controls.presetLocked = locked;
    emit presetLockedChanged();
    update();
}

void ProjectMView::setBeatSensitivity(qreal sensitivity)
{
    if (qFuzzyCompare(m_controls.beatSensitivity, sensitivity))
        return;
    m_controls.beatSensitivity = sensitivity;
    emit beatSensitivityChanged();
    update();
}

void ProjectMView::setFps(int fps)
{
    const int clamped = qBound(1, fps, 120);
    if (m_controls.fps == clamped)
        return;
    m_controls.fps = clamped;
    m_timer.setInterval(1000 / clamped);
    emit fpsChanged();
}

void ProjectMView::nextPreset()
{
    ++m_controls.pendingNext;
    update();
}

void ProjectMView::previousPreset()
{
    ++m_controls.pendingPrevious;
    update();
}

void ProjectMView::randomPreset()
{
    ++m_controls.pendingRandom;
    update();
}

ProjectMControls ProjectMView::takeControls()
{
    const ProjectMControls controls = m_controls;
    m_controls.pendingNext = 0;
    m_controls.pendingPrevious = 0;
    m_controls.pendingRandom = 0;
    return controls;
}

void ProjectMView::componentComplete()
{
    QQuickFramebufferObject::componentComplete();
    updateActive();
}

void ProjectMView::updateActive()
{
    const bool active = isVisible() && window() != nullptr;
    if (active == m_active)
        return;
    m_active = active;
    if (active) {
        m_capture->start();
        m_timer.start();
    } else {
        m_timer.stop();
        m_capture->stop();
        setAudioActive(false);
    }
}

void ProjectMView::updateApiSupport()
{
    QQuickWindow *win = window();
    if (!win || !win->isSceneGraphInitialized())
        return;
    const bool supported =
        win->rendererInterface()->graphicsApi() == QSGRendererInterface::OpenGL;
    if (supported == m_apiSupported)
        return;
    m_apiSupported = supported;
    emit apiSupportedChanged();
}

void ProjectMView::setAudioActive(bool active)
{
    if (m_audioActive == active)
        return;
    m_audioActive = active;
    emit audioActiveChanged();
}
