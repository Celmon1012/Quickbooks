'use client';

import { RefreshCw, Filter } from 'lucide-react';
import { formatDistanceToNow } from 'date-fns';

interface DashboardHeaderProps {
  userName?: string;
  userRole?: string;
  lastSyncAt?: Date | string | null;
  onRefresh?: () => void;
  onFilter?: () => void;
}

export default function DashboardHeader({
  userName = 'User',
  userRole = 'Admin',
  lastSyncAt,
  onRefresh,
  onFilter,
}: DashboardHeaderProps) {
  const getGreeting = () => {
    const hour = new Date().getHours();
    if (hour < 12) return 'Good Morning';
    if (hour < 18) return 'Good Afternoon';
    return 'Good Evening';
  };

  const formatLastSync = () => {
    if (!lastSyncAt) return 'Never synced';
    const date = typeof lastSyncAt === 'string' ? new Date(lastSyncAt) : lastSyncAt;
    return `Last synced ${formatDistanceToNow(date, { addSuffix: true })}`;
  };

  return (
    <header className="flex justify-between items-center mb-8">
      <div>
        <h2 className="text-2xl font-semibold text-gray-900">
          {getGreeting()}, {userName}
        </h2>
        <p className="text-sm text-gray-500 mt-1">
          {lastSyncAt ? formatLastSync() : 'Your latest system updates here'}
        </p>
      </div>

      <div className="flex items-center gap-4">
        {/* Action buttons */}
        <button
          onClick={onRefresh}
          className="p-2 hover:bg-gray-50 rounded-lg transition-colors"
          title="Refresh data"
        >
          <RefreshCw className="w-5 h-5 text-gray-600" />
        </button>
        <button
          onClick={onFilter}
          className="p-2 hover:bg-gray-50 rounded-lg transition-colors"
          title="Filter"
        >
          <Filter className="w-5 h-5 text-gray-600" />
        </button>

        {/* User profile */}
        <div className="flex items-center gap-3 pl-4 border-l border-gray-200">
          <div className="text-right">
            <div className="text-sm font-medium text-gray-900">{userName}</div>
            <div className="text-xs text-gray-500">{userRole}</div>
          </div>
          <div className="w-10 h-10 rounded-full bg-linear-to-br from-purple-400 to-purple-600 flex items-center justify-center">
            <span className="text-white text-sm font-semibold">
              {userName.charAt(0).toUpperCase()}
            </span>
          </div>
        </div>
      </div>
    </header>
  );
}
