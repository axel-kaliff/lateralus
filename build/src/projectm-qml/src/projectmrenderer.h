#pragma once

#include <QQuickFramebufferObject>
#include <QSize>

#include <memory>

#include "projectmview.h"

class projectM;

// Hosts the projectM engine on the Qt Quick render thread. The engine is
// created lazily in render() (its constructor compiles shaders and needs the
// scene graph's GL context current) and destroyed with the renderer.
class ProjectMRenderer : public QQuickFramebufferObject::Renderer {
public:
    explicit ProjectMRenderer(std::shared_ptr<PcmRingBuffer> ring);
    ~ProjectMRenderer() override;

    void synchronize(QQuickFramebufferObject *item) override;
    void render() override;
    QOpenGLFramebufferObject *createFramebufferObject(const QSize &size) override;

private:
    void ensureEngine();
    void drainAudio();
    void applyControls();

    std::shared_ptr<PcmRingBuffer> m_ring;
    std::unique_ptr<projectM> m_engine;
    ProjectMControls m_controls;
    QSize m_fboSize;
    bool m_sizeDirty = false;
    bool m_engineFailed = false;
    int m_appliedPresetDuration = 0;
    bool m_appliedPresetLock = false;
};
