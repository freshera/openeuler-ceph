import { HttpClientTestingModule } from '@angular/common/http/testing';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { FormsModule } from '@angular/forms';

import { configureTestBed } from '~/testing/unit-test-helper';
import { LanguageSelectorComponent } from './language-selector.component';

describe('LanguageSelectorComponent', () => {
  let component: LanguageSelectorComponent;
  let fixture: ComponentFixture<LanguageSelectorComponent>;

  configureTestBed({
    declarations: [LanguageSelectorComponent],
    imports: [FormsModule, HttpClientTestingModule]
  });

  beforeEach(() => {
    fixture = TestBed.createComponent(LanguageSelectorComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
    spyOn(component, 'reloadWindow').and.callFake(() => component.ngOnInit());
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should read current language', () => {
    // Unit tests run without --localize; Angular LOCALE_ID defaults to en-US.
    expect(component.selectedLanguage).toBe('en-US');
  });

  const expectLanguageChange = (lang: string) => {
    component.changeLanguage(lang);
    const cookie = document.cookie.split(';').filter((item) => item.includes(`cd-lang=${lang}`));
    expect(cookie.length).toBe(1);
  };

  it('should change to zh-Hans', () => {
    expectLanguageChange('zh-Hans');
  });
});
