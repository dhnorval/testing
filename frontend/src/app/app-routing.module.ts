import { NgModule } from '@angular/core';
import { RouterModule, Routes } from '@angular/router';
import { LoginComponent } from './components/login/login.component';
import { DashboardComponent } from './components/dashboard/dashboard.component';
import { StockpileListComponent } from './components/stockpile-list/stockpile-list.component';
import { StockpileFormComponent } from './components/stockpile-form/stockpile-form.component';
import { AuthGuard } from './guards/auth.guard';

const routes: Routes = [
  { path: '', redirectTo: '/dashboard', pathMatch: 'full' },
  { path: 'login', component: LoginComponent },
  { path: 'dashboard', component: DashboardComponent, canActivate: [AuthGuard] },
  { path: 'stockpiles', component: StockpileListComponent, canActivate: [AuthGuard] },
  { path: 'stockpiles/new', component: StockpileFormComponent, canActivate: [AuthGuard] },
  { path: 'stockpiles/edit/:id', component: StockpileFormComponent, canActivate: [AuthGuard] }
];

@NgModule({
  imports: [RouterModule.forRoot(routes)],
  exports: [RouterModule]
})
export class AppRoutingModule { } 