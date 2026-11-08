#include "qml/qmllibrarytracklistmodel.h"

#include <QCollator>
#include <algorithm>

#include <qnamespace.h>

#include <QObject>
#include <QQmlEngine>
#include <QSortFilterProxyModel>
#include <QStandardItemModel>
#include <QVariant>

#include "library/basetracktablemodel.h"
#include "library/columncache.h"
#include "library/starrating.h"
#include "moc_qmllibrarytracklistmodel.cpp"
#include "qml/asyncimageprovider.h"
#include "qml/qmllibrarytracklistcolumn.h"
#include "qml_owned_ptr.h"
#include "qmltrackproxy.h"
#include "track/track.h"
#include "util/assert.h"
#include "util/parented_ptr.h"

namespace mixxx {
namespace qml {
namespace {
const QHash<int, QByteArray> kRoleNames = {
        {Qt::DisplayRole, "display"},
        {Qt::DecorationRole, "decoration"},
        {QmlLibraryTrackListModel::Delegate, "delegate"},
        {QmlLibraryTrackListModel::Track, "track"},
        {QmlLibraryTrackListModel::FileURL, "file_url"},
        {QmlLibraryTrackListModel::CoverArt, "cover_art"},
};

QColor colorFromRgbCode(double colorValue) {
    if (colorValue < 0 || colorValue > 0xFFFFFF) {
        return {};
    }

    QRgb rgbValue = static_cast<QRgb>(colorValue) | 0xFF000000;
    return QColor(rgbValue);
}
} // namespace

QmlLibraryTrackListModel::QmlLibraryTrackListModel(
        const QList<QmlLibraryTrackListColumn*>& librarySource,
        QAbstractItemModel* pModel,
        QObject* pParent)
        : QIdentityProxyModel(pParent),
          m_columns() {
    m_columns.reserve(librarySource.size());
    for (const auto* pColumn : std::as_const(librarySource)) {
        m_columns.emplace_back(make_parented<QmlLibraryTrackListColumn>(this,
                pColumn->label(),
                pColumn->fillSpan(),
                pColumn->columnIdx(),
                pColumn->preferredWidth(),
                pColumn->autoHideWidth(),
                pColumn->delegate(),
                pColumn->role()));
    }

    auto* pTrackModel = dynamic_cast<TrackModel*>(pModel);
    VERIFY_OR_DEBUG_ASSERT(pTrackModel) {
        return;
    }
    pTrackModel->select();
    setSourceModel(pModel);
}

QVariant QmlLibraryTrackListModel::data(const QModelIndex& proxyIndex, int role) const {
    if (!proxyIndex.isValid()) {
        return {};
    }

    VERIFY_OR_DEBUG_ASSERT(checkIndex(proxyIndex)) {
        return {};
    }
    auto columnIdx = proxyIndex.column();
    VERIFY_OR_DEBUG_ASSERT(columnIdx >= 0 || columnIdx < m_columns.size()) {
        return {};
    }

    auto* const pTrackTableModel = qobject_cast<BaseTrackTableModel*>(sourceModel());
    auto* const pTrackModel = dynamic_cast<TrackModel*>(sourceModel());

    const auto& pColumn = m_columns[columnIdx];

    switch (role) {
    case Track: {
        if (pTrackModel == nullptr) {
            return {};
        }
        auto pTrack = make_qml_owned<QmlTrackProxy>(pTrackModel->getTrack(
                QIdentityProxyModel::mapToSource(proxyIndex)));
        return QVariant::fromValue(pTrack.get());
    }
    case Qt::DecorationRole: {
        if (pTrackTableModel == nullptr) {
            return {};
        };
        return colorFromRgbCode(QIdentityProxyModel::data(
                proxyIndex.siblingAtColumn(pTrackTableModel->fieldIndex(
                        ColumnCache::COLUMN_LIBRARYTABLE_COLOR)),
                Qt::DisplayRole)
                        .toDouble());
    }
    case CoverArt: {
        QString location;
        if (pTrackTableModel != nullptr) {
            location = QIdentityProxyModel::data(
                    proxyIndex.siblingAtColumn(pTrackTableModel->fieldIndex(
                            QStringLiteral("location"))),
                    Qt::DisplayRole)
                               .toString();
        } else if (pTrackModel != nullptr) {
            auto pTrack = pTrackModel->getTrack(
                    QIdentityProxyModel::mapToSource(proxyIndex));
            location = pTrack->getCoverInfo().coverLocation;
        }
        if (location.isEmpty()) {
            return {};
        }

        return AsyncImageProvider::trackLocationToCoverArtUrl(location);
    }
    case FileURL: {
        if (pTrackModel == nullptr) {
            return {};
        }
        return pTrackModel->getTrackUrl(QIdentityProxyModel::mapToSource(proxyIndex));
    }
    case Delegate:
        return QVariant::fromValue(pColumn->delegate());
        break;
    }
    if (pColumn->columnIdx() < 0) {
        // Use proxyIndex.column()
        return QIdentityProxyModel::data(proxyIndex, role);
    }
    QVariant value = QIdentityProxyModel::data(
            proxyIndex.siblingAtColumn(pTrackTableModel != nullptr
                            ? pTrackTableModel->fieldIndex(
                                      static_cast<ColumnCache::Column>(
                                              pColumn->columnIdx()))
                            : pColumn->columnIdx()),
            role);
#ifdef __ANDROID__
    // The rating column delivers a StarRating object; QML needs the plain star count.
    if (role == Qt::DisplayRole && value.canConvert<StarRating>()) {
        return value.value<StarRating>().starCount();
    }
#endif
    return value;
}

int QmlLibraryTrackListModel::columnCount(const QModelIndex& parent) const {
    VERIFY_OR_DEBUG_ASSERT(static_cast<QmlLibraryTrackListModel*>(
                                   parent.internalPointer()) != this) {
        return 0;
    }
    return m_columns.size();
}

QVariant QmlLibraryTrackListModel::headerData(
        int section, Qt::Orientation orientation, int role) const {
    VERIFY_OR_DEBUG_ASSERT(section >= 0 || section < m_columns.size()) {
        return {};
    }
    // TODO role
    return m_columns[section]->label();
}

QHash<int, QByteArray> QmlLibraryTrackListModel::roleNames() const {
    return kRoleNames;
}

QUrl QmlLibraryTrackListModel::getUrl(int row) const {
    auto* const pTrackModel = dynamic_cast<TrackModel*>(sourceModel());

    if (pTrackModel == nullptr) {
        // TODO search for column with role
        return {};
    }
    return pTrackModel->getTrackUrl(sourceModel()->index(row, 0));
}

QVariantList QmlLibraryTrackListModel::distinctValues(int column) const {
    QHash<QString, int> counts;
    const int rows = rowCount();
    for (int row = 0; row < rows; ++row) {
        const QString value = data(index(row, column), Qt::DisplayRole).toString().trimmed();
        if (!value.isEmpty()) {
            ++counts[value];
        }
    }
    QStringList values = counts.keys();
    QCollator collator;
    collator.setNumericMode(true);
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    std::sort(values.begin(), values.end(), [&collator](const QString& a, const QString& b) {
        return collator.compare(a, b) < 0;
    });
    QVariantList result;
    for (const QString& value : std::as_const(values)) {
        QVariantMap entry;
        entry.insert(QStringLiteral("value"), value);
        entry.insert(QStringLiteral("count"), counts.value(value));
        result << entry;
    }
    return result;
}

QmlTrackProxy* QmlLibraryTrackListModel::getTrack(int row) const {
    auto* const pTrackModel = dynamic_cast<TrackModel*>(sourceModel());

    if (pTrackModel == nullptr) {
        // TODO search for column with role
        return {};
    }
    return make_qml_owned<QmlTrackProxy>(pTrackModel->getTrack(sourceModel()->index(row, 0)));
}

QVariantMap QmlLibraryTrackListModel::trackInfo(int row) const {
    QVariantMap info;
    auto* const pTrackModel = dynamic_cast<TrackModel*>(sourceModel());
    if (pTrackModel == nullptr) {
        return info;
    }
    const TrackPointer pTrack = pTrackModel->getTrack(sourceModel()->index(row, 0));
    if (!pTrack) {
        return info;
    }
    info.insert(QStringLiteral("url"), QUrl::fromLocalFile(pTrack->getLocation()).toString());
    info.insert(QStringLiteral("title"), pTrack->getTitle());
    info.insert(QStringLiteral("artist"), pTrack->getArtist());
    info.insert(QStringLiteral("album"), pTrack->getAlbum());
    info.insert(QStringLiteral("genre"), pTrack->getGenre());
    info.insert(QStringLiteral("key"), pTrack->getKeyText());
    info.insert(QStringLiteral("bpm"), pTrack->getBpm());
    info.insert(QStringLiteral("duration"), pTrack->getDuration());
    return info;
}

QVariantList QmlLibraryTrackListModel::distinctField(const QString& field) const {
    auto* const pTrackModel = dynamic_cast<TrackModel*>(sourceModel());
    if (pTrackModel == nullptr) {
        return {};
    }
    static const QHash<QString, QString> kColumns = {
            {QStringLiteral("genre"), QStringLiteral("genre")},
            {QStringLiteral("artist"), QStringLiteral("artist")},
            {QStringLiteral("album"), QStringLiteral("album")},
            {QStringLiteral("key"), QStringLiteral("key")},
            {QStringLiteral("bpm"), QStringLiteral("bpm")},
            {QStringLiteral("rating"), QStringLiteral("rating")},
            {QStringLiteral("year"), QStringLiteral("year")},
            {QStringLiteral("folder"), QStringLiteral("location")},
    };
    const auto it = kColumns.constFind(field);
    if (it == kColumns.constEnd()) {
        return {};
    }
    const int column = pTrackModel->fieldIndex(it.value());
    if (column < 0) {
        return {};
    }
    QHash<QString, int> counts;
    const int rows = sourceModel()->rowCount();
    for (int row = 0; row < rows; ++row) {
        // The display value of the rating column is a star object: use the raw value.
        const int role = field == QLatin1String("rating") ? Qt::ToolTipRole : Qt::DisplayRole;
        QString value = sourceModel()->data(sourceModel()->index(row, column), role)
                                .toString()
                                .trimmed();
        if (field == QLatin1String("folder")) {
            const int slash = value.lastIndexOf(QLatin1Char('/'));
            value = slash > 0 ? value.left(slash) : QString();
        } else if (field == QLatin1String("bpm")) {
            bool ok = false;
            const double bpm = value.toDouble(&ok);
            value = ok && bpm > 0 ? QString::number(std::lround(bpm)) : QString();
        }
        if (!value.isEmpty()) {
            ++counts[value];
        }
    }
    QStringList values = counts.keys();
    QCollator collator;
    collator.setNumericMode(true);
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    std::sort(values.begin(), values.end(), [&collator](const QString& a, const QString& b) {
        return collator.compare(a, b) < 0;
    });
    QVariantList result;
    for (const QString& value : std::as_const(values)) {
        QVariantMap entry;
        entry.insert(QStringLiteral("value"), value);
        entry.insert(QStringLiteral("count"), counts.value(value));
        result << entry;
    }
    return result;
}

TrackModel::Capabilities QmlLibraryTrackListModel::getCapabilities() const {
    auto* const pTrackModel = dynamic_cast<TrackModel*>(sourceModel());

    if (pTrackModel != nullptr) {
        return pTrackModel->getCapabilities();
    }
    return TrackModel::Capability::None;
}
bool QmlLibraryTrackListModel::hasCapabilities(TrackModel::Capabilities caps) const {
    return (getCapabilities() & caps) == caps;
}

void QmlLibraryTrackListModel::search(const QString& searchText) {
    auto* const pTrackModel = dynamic_cast<TrackModel*>(sourceModel());
    VERIFY_OR_DEBUG_ASSERT(pTrackModel) {
        return;
    }
    pTrackModel->search(searchText);
}

void QmlLibraryTrackListModel::sort(int column, Qt::SortOrder order) {
    VERIFY_OR_DEBUG_ASSERT(column >= 0 || column < m_columns.size()) {
        return;
    }
    const auto& pColumn = m_columns[column];
    emit layoutAboutToBeChanged(QList<QPersistentModelIndex>(),
            QAbstractItemModel::VerticalSortHint);
    if (pColumn->columnIdx() < 0) {
        // Use proxyIndex.column()
        sourceModel()->sort(column, order);
        emit layoutChanged(QList<QPersistentModelIndex>(), QAbstractItemModel::VerticalSortHint);
        return;
    }
    auto* const pTrackTableModel = qobject_cast<BaseTrackTableModel*>(sourceModel());
    sourceModel()->sort(pTrackTableModel != nullptr
                    ? pTrackTableModel->fieldIndex(
                              static_cast<ColumnCache::Column>(
                                      pColumn->columnIdx()))
                    : pColumn->columnIdx(),
            order);
    emit layoutChanged(QList<QPersistentModelIndex>(), QAbstractItemModel::VerticalSortHint);
}

} // namespace qml
} // namespace mixxx
