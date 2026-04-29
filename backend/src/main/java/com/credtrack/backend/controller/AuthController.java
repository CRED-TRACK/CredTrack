package com.credtrack.backend.controller;

import com.credtrack.backend.entity.User;
import com.credtrack.backend.service.FirebaseService;
import com.credtrack.backend.service.UserService;
import com.google.firebase.auth.FirebaseToken;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;

@RestController
@RequestMapping("/auth")
public class AuthController {

    private static final Logger log = LoggerFactory.getLogger(AuthController.class);

    private final FirebaseService firebaseService;
    private final UserService userService;

    public AuthController(FirebaseService firebaseService, UserService userService) {
        this.firebaseService = firebaseService;
        this.userService = userService;
    }

    @GetMapping("/login")
    public User login(@RequestHeader("Authorization") String authHeader) {

        String token = authHeader.replace("Bearer ", "");

        FirebaseToken decoded = firebaseService.verifyToken(token);
        log.info("auth_login event=verified uid={} email={}", decoded.getUid(), decoded.getEmail());

        User user = new User();
        user.setId(decoded.getUid());
        user.setEmail(decoded.getEmail());
        user.setName(decoded.getName());
        user.setProfilePicture(decoded.getPicture());
        user.setProvider(decoded.getIssuer());
        user.setEmailVerified(decoded.isEmailVerified());
        user.setLastLogin(LocalDateTime.now());

        User saved = userService.createOrUpdateUser(user);
        log.info("auth_login event=saved uid={} email={}", saved.getId(), saved.getEmail());
        return saved;
    }
}
