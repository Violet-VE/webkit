/*
 * Copyright (C) 2014 Samsung Electronics. All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public License
 * along with this library; see the file COPYING.LIB.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#include "config.h"
#include "WebKitAccessibleInterfaceTableCell.h"

#if HAVE(ACCESSIBILITY)
#if ATK_CHECK_VERSION(2,11,90)
#include "AccessibilityObject.h"
#include "AccessibilityTable.h"
#include "AccessibilityTableCell.h"
#include "WebKitAccessibleUtil.h"
#include "WebKitAccessibleWrapperAtk.h"

using namespace WebCore;

static GPtrArray* convertToGPtrArray(const AccessibilityObject::AccessibilityChildrenVector& children)
{
    GPtrArray* array = g_ptr_array_new();
    for (const auto& child : children) {
        if (auto* atkObject = child->wrapper())
            g_ptr_array_add(array, atkObject);
    }
    return array;
}

static AccessibilityObject* core(AtkTableCell* cell)
{
    if (!WEBKIT_IS_ACCESSIBLE(cell))
        return nullptr;

    return webkitAccessibleGetAccessibilityObject(WEBKIT_ACCESSIBLE(cell));
}

GPtrArray* webkitAccessibleTableCellGetColumnHeaderCells(AtkTableCell* cell)
{
    g_return_val_if_fail(ATK_TABLE_CELL(cell), nullptr);
    returnValIfWebKitAccessibleIsInvalid(WEBKIT_ACCESSIBLE(cell), nullptr);

    AccessibilityObject* axObject = core(cell);
    if (!is<AccessibilityTableCell>(axObject))
        return nullptr;

    AccessibilityObject::AccessibilityChildrenVector columnHeaders;
    downcast<AccessibilityTableCell>(*axObject).columnHeaders(columnHeaders);

    return convertToGPtrArray(columnHeaders);
}

GPtrArray* webkitAccessibleTableCellGetRowHeaderCells(AtkTableCell* cell)
{
    g_return_val_if_fail(ATK_TABLE_CELL(cell), nullptr);
    returnValIfWebKitAccessibleIsInvalid(WEBKIT_ACCESSIBLE(cell), nullptr);

    AccessibilityObject* axObject = core(cell);
    if (!is<AccessibilityTableCell>(axObject))
        return nullptr;

    AccessibilityObject::AccessibilityChildrenVector rowHeaders;
    downcast<AccessibilityTableCell>(*axObject).rowHeaders(rowHeaders);

    return convertToGPtrArray(rowHeaders);
}

gint webkitAccessibleTableCellGetColumnSpan(AtkTableCell* cell)
{
    g_return_val_if_fail(ATK_TABLE_CELL(cell), 0);
    returnValIfWebKitAccessibleIsInvalid(WEBKIT_ACCESSIBLE(cell), 0);

    AccessibilityObject* axObject = core(cell);
    if (!is<AccessibilityTableCell>(axObject))
        return 0;

    std::pair<unsigned, unsigned> columnRange;
    downcast<AccessibilityTableCell>(*axObject).columnIndexRange(columnRange);

    return columnRange.second;
}

gint webkitAccessibleTableCellGetRowSpan(AtkTableCell* cell)
{
    g_return_val_if_fail(ATK_TABLE_CELL(cell), 0);
    returnValIfWebKitAccessibleIsInvalid(WEBKIT_ACCESSIBLE(cell), 0);

    AccessibilityObject* axObject = core(cell);
    if (!is<AccessibilityTableCell>(axObject))
        return 0;

    std::pair<unsigned, unsigned> rowRange;
    downcast<AccessibilityTableCell>(*axObject).rowIndexRange(rowRange);

    return rowRange.second;
}

gboolean webkitAccessibleTableCellGetPosition(AtkTableCell* cell, gint* row, gint* column)
{
    g_return_val_if_fail(ATK_TABLE_CELL(cell), false);
    returnValIfWebKitAccessibleIsInvalid(WEBKIT_ACCESSIBLE(cell), false);

    AccessibilityObject* axObject = core(cell);
    if (!is<AccessibilityTableCell>(axObject))
        return false;

    std::pair<unsigned, unsigned> columnRowRange;
    if (row) {
        // aria-rowindex is 1-based.
        int rowIndex = downcast<AccessibilityTableCell>(*axObject).axRowIndex() - 1;
        if (rowIndex <= -1) {
            downcast<AccessibilityTableCell>(*axObject).rowIndexRange(columnRowRange);
            rowIndex = columnRowRange.first;
        }
        *row = rowIndex;
    }
    if (column) {
        // aria-colindex is 1-based.
        int columnIndex = downcast<AccessibilityTableCell>(*axObject).axColumnIndex() - 1;
        if (columnIndex <= -1) {
            downcast<AccessibilityTableCell>(*axObject).columnIndexRange(columnRowRange);
            columnIndex = columnRowRange.first;
        }
        *column = columnIndex;
    }

    return true;
}

AtkObject* webkitAccessibleTableCellGetTable(AtkTableCell* cell)
{
    g_return_val_if_fail(ATK_TABLE_CELL(cell), nullptr);
    returnValIfWebKitAccessibleIsInvalid(WEBKIT_ACCESSIBLE(cell), nullptr);

    AccessibilityObject* axObject = core(cell);
    if (!axObject || !axObject->isTableCell())
        return nullptr;

    auto* table = atk_object_get_parent(ATK_OBJECT(axObject->wrapper()));
    if (!table || !ATK_IS_TABLE(table))
        return nullptr;

    return ATK_OBJECT(g_object_ref(table));
}

void webkitAccessibleTableCellInterfaceInit(AtkTableCellIface* iface)
{
    iface->get_column_header_cells = webkitAccessibleTableCellGetColumnHeaderCells;
    iface->get_row_header_cells = webkitAccessibleTableCellGetRowHeaderCells;
    iface->get_column_span = webkitAccessibleTableCellGetColumnSpan;
    iface->get_row_span = webkitAccessibleTableCellGetRowSpan;
    iface->get_position = webkitAccessibleTableCellGetPosition;
    iface->get_table = webkitAccessibleTableCellGetTable;
}

#endif // ATK_CHECK_VERSION(2,11,90)
#endif // HAVE(ACCESSIBILITY)
