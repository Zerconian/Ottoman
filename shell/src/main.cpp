#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "AppModel.h"
#include "Sway.h"
int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("ottoman-shell"));      // becomes the Wayland app_id sway matches on
    app.setDesktopFileName(QStringLiteral("ottoman-shell"));
    Sway sway;
    AppModel apps(&sway);
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("sway"), &sway);
    engine.rootContext()->setContextProperty(QStringLiteral("apps"), &apps);
    engine.loadFromModule("Ottoman", "Main");
    if (engine.rootObjects().isEmpty()) return 1;
    return app.exec();
}
