#pragma once
#include <QObject>
// org.ottoman.Shell on the session bus: lets session scripts (home.sh) drive the shell. Home() resets the
// launcher even when the shell is already the active window (no activation event fires then).
class ShellControl : public QObject {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.ottoman.Shell")
public:
    explicit ShellControl(QObject *parent = nullptr);
public slots:
    void Home() { emit homeRequested(); }
signals:
    void homeRequested();
};
