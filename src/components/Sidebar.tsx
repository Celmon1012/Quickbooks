'use client';

import { LayoutDashboard, FileText, TrendingUp, Target, Settings } from 'lucide-react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';

interface NavItemProps {
  icon: React.ComponentType<{ className?: string }>;
  label: string;
  href: string;
  active?: boolean;
}

function NavItem({ icon: Icon, label, href, active }: NavItemProps) {
  return (
    <Link
      href={href}
      className={`flex items-center gap-3 px-3 py-2 rounded-lg transition-colors ${
        active
          ? 'bg-purple-50 text-purple-600'
          : 'text-gray-600 hover:bg-gray-50'
      }`}
    >
      <Icon className="w-5 h-5" />
      <span className="text-sm font-medium">{label}</span>
    </Link>
  );
}

interface MenuSectionProps {
  title: string;
  children: React.ReactNode;
}

function MenuSection({ title, children }: MenuSectionProps) {
  return (
    <div>
      <div className="text-xs font-semibold text-gray-400 uppercase mb-3">
        {title}
      </div>
      <div className="space-y-1">{children}</div>
    </div>
  );
}

export default function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="fixed left-0 top-0 h-screen w-60 bg-white border-r border-gray-100 p-6 z-50">
      {/* Logo */}
      <div className="mb-10">
        <h1 className="text-2xl font-bold text-purple-600">VIRGO</h1>
        <p className="text-xs text-gray-500 mt-1">Financial Dashboard</p>
      </div>

      {/* Menu Sections */}
      <nav className="space-y-6">
        <MenuSection title="MENU">
          <NavItem
            icon={LayoutDashboard}
            label="Dashboard"
            href="/"
            active={pathname === '/'}
          />
        </MenuSection>

        <MenuSection title="REPORTS & VIEWS">
          <NavItem
            icon={FileText}
            label="P&L"
            href="/pl"
            active={pathname === '/pl'}
          />
          <NavItem
            icon={TrendingUp}
            label="Cash Flow"
            href="/cash-flow"
            active={pathname === '/cash-flow'}
          />
          <NavItem
            icon={Target}
            label="KPIs"
            href="/kpis"
            active={pathname === '/kpis'}
          />
        </MenuSection>

        <MenuSection title="SETTINGS">
          <NavItem
            icon={Settings}
            label="Configuration"
            href="/settings"
            active={pathname === '/settings'}
          />
        </MenuSection>
      </nav>
    </aside>
  );
}
