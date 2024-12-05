import { Component } from '@angular/core';
import { Router } from '@angular/router';
import { AuthService } from './services/auth.service';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.scss']
})
export class AppComponent {
  title = 'Stockpile Management';

  get isLoggedIn(): boolean {
    return this.authService.currentUserValue !== null;
  }

  constructor(
    private router: Router,
    private authService: AuthService
  ) {}

  logout(event: Event): void {
    event.preventDefault();
    this.authService.logout();
    this.router.navigate(['/login']);
  }
} 