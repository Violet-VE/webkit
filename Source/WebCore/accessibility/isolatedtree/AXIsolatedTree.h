/*
 * Copyright (C) 2019 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#pragma once

#if ENABLE(ACCESSIBILITY_ISOLATED_TREE)

#include "AXIsolatedTreeNode.h"
#include <wtf/HashMap.h>
#include <wtf/RefPtr.h>
#include <wtf/ThreadSafeRefCounted.h>

namespace WebCore {

class Page;

class AXIsolatedTree : public ThreadSafeRefCounted<AXIsolatedTree>, public CanMakeWeakPtr<AXIsolatedTree> {
    WTF_MAKE_NONCOPYABLE(AXIsolatedTree); WTF_MAKE_FAST_ALLOCATED;

public:
    static Ref<AXIsolatedTree> create();
    virtual ~AXIsolatedTree();

    static Ref<AXIsolatedTree> createTreeForPageID(uint64_t pageID);
    WEBCORE_EXPORT static Ref<AXIsolatedTree> initializePageTreeForID(uint64_t pageID, AXObjectCache&);
    WEBCORE_EXPORT static RefPtr<AXIsolatedTree> treeForPageID(uint64_t pageID);
    WEBCORE_EXPORT static RefPtr<AXIsolatedTree> treeForID(AXIsolatedTreeID);

    WEBCORE_EXPORT RefPtr<AXIsolatedTreeNode> rootNode();
    WEBCORE_EXPORT RefPtr<AXIsolatedTreeNode> focusedUIElement();
    RefPtr<AXIsolatedTreeNode> nodeForID(AXID) const;
    static RefPtr<AXIsolatedTreeNode> nodeInTreeForID(AXIsolatedTreeID, AXID);

    // Call on main thread
    void appendNodeChanges(Vector<Ref<AXIsolatedTreeNode>>&);
    void removeNode(AXID);

    void setRootNodeID(AXID);
    void setFocusedNodeID(AXID);
    
    // Call on AX thread
    WEBCORE_EXPORT void applyPendingChanges();

    WEBCORE_EXPORT void setInitialRequestInProgress(bool);
    AXIsolatedTreeID treeIdentifier() const { return m_treeID; }

private:
    AXIsolatedTree();

    static HashMap<AXIsolatedTreeID, Ref<AXIsolatedTree>>& treeIDCache();
    static HashMap<uint64_t, Ref<AXIsolatedTree>>& treePageCache();

    // Only access on AX thread requesting data.
    HashMap<AXID, Ref<AXIsolatedTreeNode>> m_readerThreadNodeMap;

    // Written to by main thread under lock, accessed and applied by AX thread.
    Vector<Ref<AXIsolatedTreeNode>> m_pendingAppends;
    Vector<AXID> m_pendingRemovals;
    AXID m_pendingFocusedNodeID;
    AXID m_pendingRootNodeID;
    Lock m_changeLogLock;

    AXIsolatedTreeID m_treeID;
    AXID m_rootNodeID { InvalidAXID };
    AXID m_focusedNodeID { InvalidAXID };
    bool m_initialRequestInProgress;
};

} // namespace WebCore

#endif
