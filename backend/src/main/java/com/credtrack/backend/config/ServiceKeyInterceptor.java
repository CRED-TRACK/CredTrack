package com.credtrack.backend.config;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

@Component
public class ServiceKeyInterceptor implements HandlerInterceptor {

    private final String serviceKey;

    public ServiceKeyInterceptor(@Value("${app.internal.service-key}") String serviceKey) {
        this.serviceKey = serviceKey;
    }

    @Override
    public boolean preHandle(HttpServletRequest request,
                             HttpServletResponse response,
                             Object handler) throws Exception {
        String provided = request.getHeader("X-Service-Key");
        if (serviceKey.equals(provided)) {
            return true;
        }
        response.sendError(HttpStatus.UNAUTHORIZED.value(), "Invalid or missing X-Service-Key");
        return false;
    }
}
