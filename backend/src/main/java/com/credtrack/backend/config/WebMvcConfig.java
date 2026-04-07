package com.credtrack.backend.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebMvcConfig implements WebMvcConfigurer {

    private final ServiceKeyInterceptor serviceKeyInterceptor;

    public WebMvcConfig(ServiceKeyInterceptor serviceKeyInterceptor) {
        this.serviceKeyInterceptor = serviceKeyInterceptor;
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(serviceKeyInterceptor)
                .addPathPatterns("/internal/**");
    }
}
