#pragma once

#include <QQuickFramebufferObject>
#include <QString>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

#include <memory>

#include "pcmringbuffer.h"
#include "pipewirecapture.h"

// Control state handed from the GUI thread to the renderer inside
// synchronize(), where the GUI thread is blocked — no locking needed.
struct ProjectMControls {
    QString presetPath;
    int presetDuration = 20;
    bool shuffle = true;
    bool presetLocked = false;
    qreal beatSensitivity = 1.0;
    int fps = 30;
    int pendingNext = 0;
    int pendingPrevious = 0;
    int pendingRandom = 0;
};

// Renders projectM (Milkdrop) into the Qt Quick scene graph, fed by the
// default sink's monitor audio. Capture and the frame timer run only while
// the item is visible in a window, so a closed popup costs zero CPU.
class ProjectMView : public QQuickFramebufferObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(ProjectMView)
    Q_PROPERTY(QString presetPath READ presetPath WRITE setPresetPath NOTIFY presetPathChanged)
    Q_PROPERTY(int presetDuration READ presetDuration WRITE setPresetDuration NOTIFY presetDurationChanged)
    Q_PROPERTY(bool shuffle READ shuffle WRITE setShuffle NOTIFY shuffleChanged)
    Q_PROPERTY(bool presetLocked READ presetLocked WRITE setPresetLocked NOTIFY presetLockedChanged)
    Q_PROPERTY(qreal beatSensitivity READ beatSensitivity WRITE setBeatSensitivity NOTIFY beatSensitivityChanged)
    Q_PROPERTY(int fps READ fps WRITE setFps NOTIFY fpsChanged)
    Q_PROPERTY(bool apiSupported READ apiSupported NOTIFY apiSupportedChanged)
    Q_PROPERTY(bool audioActive READ audioActive NOTIFY audioActiveChanged)

public:
    explicit ProjectMView(QQuickItem *parent = nullptr);
    ~ProjectMView() override;

    Renderer *createRenderer() const override;

    QString presetPath() const { return m_controls.presetPath; }
    void setPresetPath(const QString &path);
    int presetDuration() const { return m_controls.presetDuration; }
    void setPresetDuration(int seconds);
    bool shuffle() const { return m_controls.shuffle; }
    void setShuffle(bool shuffle);
    bool presetLocked() const { return m_controls.presetLocked; }
    void setPresetLocked(bool locked);
    qreal beatSensitivity() const { return m_controls.beatSensitivity; }
    void setBeatSensitivity(qreal sensitivity);
    int fps() const { return m_controls.fps; }
    void setFps(int fps);
    bool apiSupported() const { return m_apiSupported; }
    bool audioActive() const { return m_audioActive; }

    Q_INVOKABLE void nextPreset();
    Q_INVOKABLE void previousPreset();
    Q_INVOKABLE void randomPreset();

    // Called by the renderer during synchronize() (GUI thread blocked).
    ProjectMControls takeControls();
    std::shared_ptr<PcmRingBuffer> ring() const { return m_ring; }

signals:
    void presetPathChanged();
    void presetDurationChanged();
    void shuffleChanged();
    void presetLockedChanged();
    void beatSensitivityChanged();
    void fpsChanged();
    void apiSupportedChanged();
    void audioActiveChanged();

protected:
    void componentComplete() override;

private:
    void updateActive();
    void updateApiSupport();
    void setAudioActive(bool active);

    std::shared_ptr<PcmRingBuffer> m_ring;
    std::unique_ptr<PipeWireCapture> m_capture;
    QTimer m_timer;
    ProjectMControls m_controls;
    bool m_active = false;
    bool m_apiSupported = true;
    bool m_audioActive = false;
};
