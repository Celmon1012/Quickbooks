'use client';

import Sidebar from './Sidebar';

interface RootLayoutProps {
  children: React.ReactNode;
}

export default function RootLayout({ children }: RootLayoutProps) {
  return (
    <div className="min-h-screen gradient-dashboard">
      <Sidebar />
      <main className="ml-60 p-8">
        <div className="bg-white rounded-card-2xl shadow-card-elevated p-8 min-h-[calc(100vh-4rem)]">
          {children}
        </div>
      </main>
    </div>
  );
}
