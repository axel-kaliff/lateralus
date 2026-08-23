#include "projectmrenderer.h"

#include <QOpenGLContext>
#include <QOpenGLFramebufferObject>
#include <QOpenGLFunctions>
#include <QQuickOpenGLUtils>
#include <QtGlobal>

#include <libprojectM/PCM.hpp>
#include <libprojectM/projectM.hpp>

ProjectMRenderer::ProjectMRenderer(std::shared_ptr<PcmRingBuffer> ring)
    : m_ring(std::move(ring))
{
}

ProjectMRenderer::~ProjectMRenderer() = default;

void ProjectMRenderer::synchronize(QQuickFramebufferObject *item)
{
    // The GUI thread is blocked here — plain reads are safe.
    auto *view = static_cast<ProjectMView *>(item);
    const ProjectMControls fresh = view->takeControls();
    m_controls.pendingNext += fresh.pendingNext;
    m_controls.pendingPrevious += fresh.pendingPrevious;
    m_controls.pendingRandom += fresh.pendingRandom;
    m_controls.presetPath = fresh.presetPath;
    m_controls.presetDuration = fresh.presetDuration;
    m_controls.shuffle = fresh.shuffle;
    m_controls.presetLocked = fresh.presetLocked;
    m_controls.beatSensitivity = fresh.beatSensitivity;
    m_controls.fps = fresh.fps;
}

QOpenGLFramebufferObject *ProjectMRenderer::createFramebufferObject(const QSize &size)
{
    m_fboSize = size;
    m_sizeDirty = true;
    QOpenGLFramebufferObjectFormat format;
    format.setAttachment(QOpenGLFramebufferObject::CombinedDepthStencil);
    return new QOpenGLFramebufferObject(size, format);
}

void ProjectMRenderer::render()
{
    if (!QOpenGLContext::currentContext())
        return; // non-GL scene graph backend; the item stays blank

    ensureEngine();
    if (m_engine) {
        if (m_sizeDirty) {
            m_engine->projectM_resetGL(m_fboSize.width(), m_fboSize.height());
            m_sizeDirty = false;
        }
        drainAudio();
        applyControls();
        try {
            m_engine->renderFrame();
        } catch (...) {
            qWarning("projectm-qml: renderFrame threw; disabling engine");
            m_engine.reset();
            m_engineFailed = true;
        }

        // projectM writes meaningless alpha and the scene graph blends the
        // FBO texture, so dark pixels turn transparent without this.
        QOpenGLFunctions *gl = QOpenGLContext::currentContext()->functions();
        gl->glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_TRUE);
        gl->glClearColor(0.0F, 0.0F, 0.0F, 1.0F);
        gl->glClear(GL_COLOR_BUFFER_BIT);
        gl->glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
    }

    // Must be the last call: it also resets the framebuffer binding.
    QQuickOpenGLUtils::resetOpenGLState();
}

void ProjectMRenderer::ensureEngine()
{
    if (m_engine || m_engineFailed)
        return;

    projectM::Settings settings;
    settings.meshX = 32;
    settings.meshY = 24;
    settings.fps = m_controls.fps;
    settings.textureSize = 512;
    settings.windowWidth = m_fboSize.width();
    settings.windowHeight = m_fboSize.height();
    settings.presetURL = m_controls.presetPath.toStdString();
    settings.titleFontURL = "/usr/share/projectM/fonts/Vera.ttf";
    settings.menuFontURL = "/usr/share/projectM/fonts/VeraMono.ttf";
    settings.datadir = "/usr/share/projectM";
    settings.smoothPresetDuration = 5;
    settings.presetDuration = m_controls.presetDuration;
    settings.hardcutEnabled = false;
    settings.hardcutDuration = 60;
    settings.hardcutSensitivity = 2.0F;
    settings.beatSensitivity = static_cast<float>(m_controls.beatSensitivity);
    settings.aspectCorrection = true;
    settings.easterEgg = 0.0F;
    settings.shuffleEnabled = m_controls.shuffle;
    settings.softCutRatingsEnabled = false;

    try {
        m_engine = std::make_unique<projectM>(settings);
        m_sizeDirty = true;
        m_appliedPresetDuration = m_controls.presetDuration;
        m_appliedPresetLock = false;
        if (m_controls.shuffle)
            m_engine->selectRandom(true);
    } catch (...) {
        qWarning("projectm-qml: engine construction failed; visualizer disabled");
        m_engine.reset();
        m_engineFailed = true;
    }
}

void ProjectMRenderer::drainAudio()
{
    float chunk[2048];
    std::size_t count = 0;
    // Drain everything buffered since the last frame; PipeWire delivers whole
    // frames, so counts stay even and L/R pairing is preserved.
    while ((count = m_ring->read(chunk, sizeof(chunk) / sizeof(chunk[0]))) > 0) {
        m_engine->pcm()->addPCMfloat_2ch(chunk, static_cast<int>(count));
        if (count < sizeof(chunk) / sizeof(chunk[0]))
            break;
    }
}

void ProjectMRenderer::applyControls()
{
    try {
        if (m_controls.presetLocked != m_appliedPresetLock) {
            m_engine->setPresetLock(m_controls.presetLocked);
            m_appliedPresetLock = m_controls.presetLocked;
        }
        if (m_controls.presetDuration != m_appliedPresetDuration) {
            m_engine->changePresetDuration(m_controls.presetDuration);
            m_appliedPresetDuration = m_controls.presetDuration;
        }
        for (; m_controls.pendingNext > 0; --m_controls.pendingNext)
            m_engine->selectNext(true);
        for (; m_controls.pendingPrevious > 0; --m_controls.pendingPrevious)
            m_engine->selectPrevious(true);
        for (; m_controls.pendingRandom > 0; --m_controls.pendingRandom)
            m_engine->selectRandom(true);
    } catch (...) {
        qWarning("projectm-qml: preset control threw; command dropped");
        m_controls.pendingNext = 0;
        m_controls.pendingPrevious = 0;
        m_controls.pendingRandom = 0;
    }
}
